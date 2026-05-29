require('dotenv').config();
const { Client, GatewayIntentBits, REST, Routes, SlashCommandBuilder, EmbedBuilder } = require('discord.js');
const http = require('http');
const fs = require('fs');
const path = require('path');

const {
    DISCORD_TOKEN,
    CLIENT_ID,
    GUILD_ID,
    PORT = '3000'
} = process.env;

const ANNOUNCE_CHANNEL_ID = '1509993539176759479';
const ADMIN_ROLE_ID = '1510000218454888559';
const WELCOME_CHANNEL_ID = '1509986939372179639';
const AUTO_ROLE_ID = '1510000443386892329';
const COOLDOWN_MS = 60 * 60 * 1000; // 1 hour

// ── Persistent File Paths ─────────────────────────────────────
const KEYS_FILE = path.join(__dirname, 'keys.json');
const COOLDOWNS_FILE = path.join(__dirname, 'cooldowns.json');

// ── Key storage maps ──────────────────────────────────────────
// validKeys: key => { expiresAt, generatedBy, duration }
let validKeys = new Map();
let userCooldown = new Map(); // userId => generatedAt

// Helper to check if a user has the Admin role
function hasAdminRole(member) {
    if (!member) return false;
    const roles = member.roles;
    if (Array.isArray(roles)) {
        return roles.includes(ADMIN_ROLE_ID);
    }
    return roles.cache.has(ADMIN_ROLE_ID);
}

// Load data from disk if it exists
function loadData() {
    try {
        if (fs.existsSync(KEYS_FILE)) {
            const data = JSON.parse(fs.readFileSync(KEYS_FILE, 'utf8'));
            validKeys = new Map();
            for (const [k, val] of Object.entries(data)) {
                if (typeof val === 'number') {
                    // Upgrade old key format to new object format safely
                    validKeys.set(k, { expiresAt: val, generatedBy: 'unknown', duration: '1h' });
                } else {
                    validKeys.set(k, val);
                }
            }
            console.log(`[LumoHub] Loaded ${validKeys.size} keys from disk.`);
        }
        if (fs.existsSync(COOLDOWNS_FILE)) {
            const data = JSON.parse(fs.readFileSync(COOLDOWNS_FILE, 'utf8'));
            userCooldown = new Map(Object.entries(data));
            console.log(`[LumoHub] Loaded ${userCooldown.size} cooldowns from disk.`);
        }
    } catch (e) {
        console.error('[LumoHub] Load data error:', e.message);
    }
}

// Save data to disk
function saveData() {
    try {
        const keysObj = Object.fromEntries(validKeys);
        fs.writeFileSync(KEYS_FILE, JSON.stringify(keysObj, null, 2));

        const cooldownsObj = Object.fromEntries(userCooldown);
        fs.writeFileSync(COOLDOWNS_FILE, JSON.stringify(cooldownsObj, null, 2));
    } catch (e) {
        console.error('[LumoHub] Save data error:', e.message);
    }
}

function generateKey() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    const part = () => Array.from({ length: 4 }, () => chars[Math.floor(Math.random() * chars.length)]).join('');
    return `LUMO-${part()}-${part()}-${part()}`;
}

function formatCountdown(ms) {
    if (ms > 365 * 24 * 60 * 60 * 1000) return 'Lifetime';
    const days = Math.floor(ms / (24 * 60 * 60 * 1000));
    const hours = Math.floor((ms % (24 * 60 * 60 * 1000)) / (60 * 60 * 1000));
    const minutes = Math.floor((ms % (60 * 60 * 1000)) / 60000);
    
    let str = '';
    if (days > 0) str += `${days}d `;
    if (hours > 0) str += `${hours}h `;
    str += `${minutes}m`;
    return str;
}

function pruneExpired() {
    const now = Date.now();
    let changed = false;
    for (const [key, data] of validKeys.entries()) {
        if (data.expiresAt < now) {
            validKeys.delete(key);
            changed = true;
        }
    }
    if (changed) saveData();
}

// Load initial data
loadData();

// ── HTTP server (Roblox reads /keys to validate) ──────────────
const server = http.createServer((req, res) => {
    pruneExpired();
    if (req.url === '/keys' || req.url === '/') {
        const body = validKeys.size > 0
            ? Array.from(validKeys.keys()).join('\n')
            : 'NO_VALID_KEYS';
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        res.end(body);
    } else {
        res.writeHead(404);
        res.end('Not found');
    }
});

server.listen(PORT, () => {
    console.log(`[LumoHub] HTTP key server running on port ${PORT}`);
});

// ── Discord slash commands ────────────────────────────────────
const commands = [
    new SlashCommandBuilder()
        .setName('generate')
        .setDescription('Generate a 1-hour LumoHub key')
        .toJSON(),
    new SlashCommandBuilder()
        .setName('keyinfo')
        .setDescription('Check details of your active keys')
        .toJSON(),
    new SlashCommandBuilder()
        .setName('revoke')
        .setDescription('Revoke all active keys & cooldown of a user (Admin Only)')
        .addUserOption(option => 
            option.setName('user')
                .setDescription('The user whose keys and cooldown you want to revoke')
                .setRequired(true))
        .toJSON(),
    new SlashCommandBuilder()
        .setName('createkey')
        .setDescription('Create a custom duration premium key (Admin Only)')
        .addStringOption(option =>
            option.setName('duration')
                .setDescription('The duration of the key')
                .setRequired(true)
                .addChoices(
                    { name: '1 Hour', value: '1h' },
                    { name: '24 Hours', value: '24h' },
                    { name: '2 Weeks', value: '2w' },
                    { name: '1 Month', value: '1m' },
                    { name: '6 Months', value: '6m' },
                    { name: '1 Year', value: '1y' },
                    { name: 'Lifetime', value: 'lifetime' }
                ))
        .toJSON()
];

const rest = new REST({ version: '10' }).setToken(DISCORD_TOKEN);

async function registerCommands() {
    await rest.put(Routes.applicationGuildCommands(CLIENT_ID, GUILD_ID), { body: commands });
    console.log('[LumoHub] Slash commands registered.');
}

// ── Discord client ────────────────────────────────────────────
const client = new Client({ 
    intents: [
        GatewayIntentBits.Guilds,
        GatewayIntentBits.GuildMembers
    ] 
});

client.once('ready', () => {
    console.log(`[LumoHub] Logged in as ${client.user.tag}`);
    client.user.setActivity('LumoHub | /generate');
    setInterval(pruneExpired, 5 * 60 * 1000);
});

// Welcome Message and Auto-Role Logic
client.on('guildMemberAdd', async member => {
    // 1. Assign Auto-Role
    try {
        const role = member.guild.roles.cache.get(AUTO_ROLE_ID);
        if (role) {
            await member.roles.add(role);
            console.log(`[LumoHub] Auto-role ${role.name} assigned to ${member.user.tag}`);
        } else {
            console.warn(`[LumoHub] Auto-role with ID ${AUTO_ROLE_ID} not found in cache.`);
        }
    } catch (err) {
        console.error('[LumoHub] Failed to assign auto-role:', err.message);
    }

    // 2. Send Embedded Welcome Message
    try {
        const channel = member.guild.channels.cache.get(WELCOME_CHANNEL_ID);
        if (channel) {
            const welcomeEmbed = new EmbedBuilder()
                .setTitle('✨ Welcome to LumoHub! ✨')
                .setDescription(`Welcome to the server, ${member}! We're thrilled to have you here.\n\n🔑 Use the **/generate** command to get your 1-hour premium key and unlock our Roblox exploit suite!\n\n💬 Be sure to check out the server channels and enjoy your stay!`)
                .setColor(0xFECC23) // LumoHub Golden Hex
                .setThumbnail(member.user.displayAvatarURL({ forceStatic: true, size: 256 }))
                .setFooter({ text: 'LumoHub Bot • Premium Exploiting' })
                .setTimestamp();

            await channel.send({ content: `Welcome ${member}!`, embeds: [welcomeEmbed] });
            console.log(`[LumoHub] Welcome message sent for ${member.user.tag}`);
        } else {
            console.warn(`[LumoHub] Welcome channel with ID ${WELCOME_CHANNEL_ID} not found.`);
        }
    } catch (err) {
        console.error('[LumoHub] Failed to send welcome message:', err.message);
    }
});

client.on('interactionCreate', async interaction => {
    if (!interaction.isChatInputCommand()) return;

    const { commandName, user, guildId, member } = interaction;

    if (guildId !== GUILD_ID) {
        return interaction.reply({ content: '❌ Use this in the **LumoHub** server!', ephemeral: true });
    }

    // ── /generate (1-hour key, 1-hour cooldown) ────────────────
    if (commandName === 'generate') {
        const now = Date.now();
        const lastGen = userCooldown.get(user.id);

        if (lastGen && now - lastGen < COOLDOWN_MS) {
            const remaining = COOLDOWN_MS - (now - lastGen);
            const minutesLeft = Math.ceil(remaining / 60000);
            return interaction.reply({
                content: `⏳ You already have an active key!\nTry again in **${minutesLeft}m**.`,
                ephemeral: true
            });
        }

        const key = generateKey();
        validKeys.set(key, {
            expiresAt: now + COOLDOWN_MS,
            generatedBy: user.id,
            duration: '1h'
        });
        userCooldown.set(user.id, now);
        saveData();

        // Private reply
        const privateEmbed = new EmbedBuilder()
            .setColor(0x7c3aed)
            .setTitle('🔑 LumoHub Key Generated')
            .setDescription(`\`\`\`${key}\`\`\``)
            .addFields(
                { name: '⏳ Expires', value: '**1 hour**', inline: true },
                { name: '📋 Usage', value: 'Paste this when the Roblox script asks', inline: true }
            )
            .setFooter({ text: 'LumoHub • discord.gg/KeJDfYV4QR' })
            .setTimestamp();

        await interaction.reply({ embeds: [privateEmbed], ephemeral: true });

        // Public announcement
        try {
            const ch = await client.channels.fetch(ANNOUNCE_CHANNEL_ID);
            if (ch) {
                const publicEmbed = new EmbedBuilder()
                    .setColor(0x7c3aed)
                    .setDescription(`🔑 **${user.username}** redeemed a **1-hour free key!**`)
                    .setFooter({ text: 'LumoHub • Use /generate to get yours!' })
                    .setTimestamp();
                await ch.send({ embeds: [publicEmbed] });
            }
        } catch (e) {
            console.error('[LumoHub] Announce error:', e.message);
        }
    }

    // ── /keyinfo ──────────────────────────────────────────────
    if (commandName === 'keyinfo') {
        pruneExpired();
        
        // Find keys generated by this user
        const myKeys = [];
        const now = Date.now();
        for (const [key, data] of validKeys.entries()) {
            if (data.generatedBy === user.id) {
                myKeys.push({ key, expiresAt: data.expiresAt, duration: data.duration });
            }
        }

        if (myKeys.length === 0) {
            return interaction.reply({ content: '❌ You have no active keys. Use `/generate` to get one!', ephemeral: true });
        }

        const embed = new EmbedBuilder()
            .setColor(0x7c3aed)
            .setTitle('⏳ Your Active Keys')
            .setFooter({ text: 'LumoHub • discord.gg/KeJDfYV4QR' });

        myKeys.forEach((k, index) => {
            const remaining = k.expiresAt - now;
            embed.addFields({
                name: `Key #${index + 1} (${k.duration})`,
                value: `\`\`\`${k.key}\`\`\`\n**Expires in:** ${formatCountdown(remaining)}`
            });
        });

        return interaction.reply({ embeds: [embed], ephemeral: true });
    }

    // ── /revoke (Admin Only) ──────────────────────────────────
    if (commandName === 'revoke') {
        if (!hasAdminRole(member)) {
            return interaction.reply({ content: '❌ You do not have permission to use this command!', ephemeral: true });
        }

        const targetUser = interaction.options.getUser('user');
        
        // Remove target user's cooldown
        userCooldown.delete(targetUser.id);

        // Remove any keys owned by the target user
        let keysRevokedCount = 0;
        for (const [key, data] of validKeys.entries()) {
            if (data.generatedBy === targetUser.id) {
                validKeys.delete(key);
                keysRevokedCount++;
            }
        }

        saveData();

        const embed = new EmbedBuilder()
            .setColor(0xef4444)
            .setTitle('🚫 Access Revoked')
            .setDescription(`Successfully revoked access for **${targetUser.username}**!`)
            .addFields(
                { name: '👥 User ID', value: `\`${targetUser.id}\``, inline: true },
                { name: '🔑 Keys Revoked', value: `**${keysRevokedCount}**`, inline: true },
                { name: '⏳ Cooldown Cleared', value: 'Yes', inline: true }
            )
            .setTimestamp();

        return interaction.reply({ embeds: [embed] });
    }

    // ── /createkey (Admin Only) ───────────────────────────────
    if (commandName === 'createkey') {
        if (!hasAdminRole(member)) {
            return interaction.reply({ content: '❌ You do not have permission to use this command!', ephemeral: true });
        }

        const durationChoice = interaction.options.getString('duration');
        const now = Date.now();
        
        // Map durations to milliseconds
        let durationMs = 0;
        let durationLabel = '';

        switch (durationChoice) {
            case '1h':
                durationMs = 60 * 60 * 1000;
                durationLabel = '1 Hour';
                break;
            case '24h':
                durationMs = 24 * 60 * 60 * 1000;
                durationLabel = '24 Hours';
                break;
            case '2w':
                durationMs = 14 * 24 * 60 * 60 * 1000;
                durationLabel = '2 Weeks';
                break;
            case '1m':
                durationMs = 30 * 24 * 60 * 60 * 1000;
                durationLabel = '1 Month';
                break;
            case '6m':
                durationMs = 180 * 24 * 60 * 60 * 1000;
                durationLabel = '6 Months';
                break;
            case '1y':
                durationMs = 365 * 24 * 60 * 60 * 1000;
                durationLabel = '1 Year';
                break;
            case 'lifetime':
                durationMs = 100 * 365 * 24 * 60 * 60 * 1000; // 100 years
                durationLabel = 'Lifetime';
                break;
        }

        const key = generateKey();
        validKeys.set(key, {
            expiresAt: now + durationMs,
            generatedBy: user.id, // Marked as generated by the admin
            duration: durationLabel
        });
        saveData();

        const embed = new EmbedBuilder()
            .setColor(0x10b981)
            .setTitle('💎 Custom Premium Key Created')
            .setDescription(`\`\`\`${key}\`\`\``)
            .addFields(
                { name: '⏳ Duration', value: `**${durationLabel}**`, inline: true },
                { name: '👮 Created By', value: `<@${user.id}>`, inline: true }
            )
            .setFooter({ text: 'LumoHub • Premium Key' })
            .setTimestamp();

        return interaction.reply({ embeds: [embed] });
    }
});

registerCommands()
    .then(() => client.login(DISCORD_TOKEN))
    .catch(console.error);
