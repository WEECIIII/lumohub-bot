require('dotenv').config();
const { Client, GatewayIntentBits, REST, Routes, SlashCommandBuilder, EmbedBuilder, ActionRowBuilder, StringSelectMenuBuilder, ButtonBuilder, ButtonStyle, ChannelType, PermissionsBitField } = require('discord.js');
const http = require('http');
const fs = require('fs');
const path = require('path');
const axios = require('axios');

const {
    DISCORD_TOKEN,
    CLIENT_ID,
    GUILD_ID,
    PORT = '3000',
    GITHUB_TOKEN
} = process.env;

const ANNOUNCE_CHANNEL_ID = '1509993539176759479';
const OWNER_ROLE_ID = '1509998989813088521';
const KEYS_ROLE_ID = '1510000218454888559';
const WELCOME_CHANNEL_ID = '1509986939372179639';
const AUTO_ROLE_ID = '1510000443386892329';
const COOLDOWN_MS = 60 * 60 * 1000; // 1 hour

// ── Persistent Cloud Database ─────────────────────────────────────
const DB_GIST_ID = '04e038c9d00af7930b2d34ffdc7d9ed9';

// ── Key storage maps ──────────────────────────────────────────
// validKeys: key => { expiresAt, generatedBy, duration }
let validKeys = new Map();
let userCooldown = new Map(); // userId => generatedAt

// Helper to check if a user has the Keys Role OR the Owner Role (can access key commands)
function hasKeysRole(member) {
    if (!member) return false;
    const roles = member.roles;
    const checkRole = (roleId) => {
        if (Array.isArray(roles)) {
            return roles.includes(roleId);
        }
        return roles.cache.has(roleId);
    };
    return checkRole(KEYS_ROLE_ID) || checkRole(OWNER_ROLE_ID);
}

// Helper to check if a user has the Owner Role (can access admin/welcome commands)
function hasOwnerRole(member) {
    if (!member) return false;
    const roles = member.roles;
    if (Array.isArray(roles)) {
        return roles.includes(OWNER_ROLE_ID);
    }
    return roles.cache.has(OWNER_ROLE_ID);
}

// Load data from Cloud Database
async function loadData() {
    if (!GITHUB_TOKEN) {
        console.error('[LumoHub DB] ERROR: GITHUB_TOKEN is missing! DB will not save.');
        return;
    }
    try {
        console.log('[LumoHub DB] Fetching database from cloud...');
        const response = await axios.get(`https://api.github.com/gists/${DB_GIST_ID}`, {
            headers: { Authorization: `token ${GITHUB_TOKEN}` }
        });
        const files = response.data.files;
        
        if (files['keys.json'] && files['keys.json'].content) {
            const parsedKeys = JSON.parse(files['keys.json'].content);
            validKeys = new Map();
            for (const [k, val] of Object.entries(parsedKeys)) {
                if (typeof val === 'number') {
                    validKeys.set(k, { expiresAt: val, generatedBy: 'unknown', duration: '1h' });
                } else {
                    validKeys.set(k, val);
                }
            }
            console.log(`[LumoHub DB] Loaded ${validKeys.size} keys from cloud.`);
        }
        
        if (files['cooldowns.json'] && files['cooldowns.json'].content) {
            const parsedCD = JSON.parse(files['cooldowns.json'].content);
            userCooldown = new Map(Object.entries(parsedCD));
            console.log(`[LumoHub DB] Loaded ${userCooldown.size} cooldowns from cloud.`);
        }
    } catch (e) {
        console.error('[LumoHub DB] Load data error:', e.message);
    }
}

// Save data to Cloud Database
async function saveData() {
    if (!GITHUB_TOKEN) return;
    try {
        const keysObj = Object.fromEntries(validKeys);
        const cdObj = Object.fromEntries(userCooldown);
        
        await axios.patch(`https://api.github.com/gists/${DB_GIST_ID}`, {
            files: {
                'keys.json': { content: JSON.stringify(keysObj, null, 2) },
                'cooldowns.json': { content: JSON.stringify(cdObj, null, 2) }
            }
        }, {
            headers: { Authorization: `token ${GITHUB_TOKEN}` }
        });
    } catch (e) {
        console.error('[LumoHub DB] Save data error:', e.message);
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

// Load initial data from cloud, then start discord bot
loadData().then(() => {
    registerCommands()
        .then(() => client.login(DISCORD_TOKEN))
        .catch(console.error);
});

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
        .setDescription('Create custom duration premium keys (Admin Only)')
        .addStringOption(option =>
            option.setName('duration')
                .setDescription('The duration of the keys')
                .setRequired(true)
                .addChoices(
                    { name: '1 Minute', value: '1min' },
                    { name: '1 Hour', value: '1h' },
                    { name: '24 Hours', value: '24h' },
                    { name: '2 Weeks', value: '2w' },
                    { name: '1 Month', value: '1m' },
                    { name: '6 Months', value: '6m' },
                    { name: '1 Year', value: '1y' },
                    { name: 'Lifetime', value: 'lifetime' }
                ))
        .addIntegerOption(option =>
            option.setName('amount')
                .setDescription('Number of keys to generate (default 1, max 50)')
                .setRequired(false)
                .setMinValue(1)
                .setMaxValue(50))
        .toJSON(),
    new SlashCommandBuilder()
        .setName('testwelcome')
        .setDescription('Test the welcome embed and message in the welcome channel (Admin Only)')
        .toJSON(),
    new SlashCommandBuilder()
        .setName('poststatus')
        .setDescription('Post the LumoHub game execution status to the status channel (Admin Only)')
        .toJSON(),
    new SlashCommandBuilder()
        .setName('setuptickets')
        .setDescription('Setup the ticket system panel (Admin Only)')
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
        GatewayIntentBits.GuildMembers,
        GatewayIntentBits.GuildMessages,
        GatewayIntentBits.MessageContent
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
                .setDescription(`Welcome to the server, ${member}! We're thrilled to have you here.\n\n🔑 Use the **/generate** command to get your 1-hour premium key and unlock our Roblox exploit suite!\n\n💬 Be sure to check out the server channels and enjoy your stay!\n\n📖 **Remember to read <#1510024611029581925> for important information!**`)
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
    if (interaction.isChatInputCommand()) {
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

        // Private reply in channel
        const privateEmbed = new EmbedBuilder()
            .setColor(0x7c3aed)
            .setTitle('🔑 LumoHub Key Generated')
            .setDescription(`\`\`\`${key}\`\`\`\nI have also sent this key to your DMs so you don't lose it!`)
            .addFields(
                { name: '⏳ Expires', value: '**1 hour**', inline: true },
                { name: '📋 Usage', value: 'Paste this when the Roblox script asks', inline: true }
            )
            .setFooter({ text: 'LumoHub • discord.gg/qkCRXBeEpB' })
            .setTimestamp();

        await interaction.reply({ embeds: [privateEmbed], ephemeral: true });

        // DM the user the key
        try {
            const dmEmbed = new EmbedBuilder()
                .setColor(0x7c3aed)
                .setTitle('🔑 Your LumoHub Premium Key')
                .setDescription(`Here is your key so you don't lose it!\n\`\`\`${key}\`\`\`\n⏳ You can create a new key after 1 hour.\nℹ️ If you want to check how much time is left on your active key, use the **/keyinfo** command!`)
                .addFields(
                    { name: '⏳ Expires In', value: '**1 hour**', inline: true }
                )
                .setFooter({ text: 'LumoHub Bot' })
                .setTimestamp();
            await user.send({ embeds: [dmEmbed] });
        } catch (err) {
            console.warn(`[LumoHub] Could not send DM to ${user.tag} (DMs might be closed).`);
        }

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

    // ── /revoke (Keys Role or Owner Only) ─────────────────────
    if (commandName === 'revoke') {
        if (!hasKeysRole(member)) {
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

    // ── /createkey (Keys Role or Owner Only) ──────────────────
    if (commandName === 'createkey') {
        if (!hasKeysRole(member)) {
            return interaction.reply({ content: '❌ You do not have permission to use this command!', ephemeral: true });
        }

        const durationChoice = interaction.options.getString('duration');
        const now = Date.now();
        
        // Map durations to milliseconds
        let durationMs = 0;
        let durationLabel = '';

        switch (durationChoice) {
            case '1min':
                durationMs = 60 * 1000;
                durationLabel = '1 Minute';
                break;
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
            default:
                durationMs = 60 * 1000; // Default to 1 minute
                durationLabel = durationChoice || 'Unknown (1m)';
                break;
        }

        const amount = interaction.options.getInteger('amount') || 1;
        const generatedKeys = [];

        for (let i = 0; i < amount; i++) {
            const key = generateKey();
            validKeys.set(key, {
                expiresAt: now + durationMs,
                generatedBy: user.id, // Marked as generated by the admin
                duration: durationLabel
            });
            generatedKeys.push(key);
        }
        saveData();

        // If generating 1 key, format nicely
        let keysText = '';
        if (amount === 1) {
            keysText = `\`\`\`${generatedKeys[0]}\`\`\``;
        } else {
            // For multiple keys, list them line by line
            keysText = `\`\`\`\n${generatedKeys.join('\n')}\n\`\`\``;
        }

        const embed = new EmbedBuilder()
            .setColor(0x10b981)
            .setTitle(`💎 ${amount} Custom Premium Key(s) Created`)
            .setDescription(keysText)
            .addFields(
                { name: '⏳ Duration', value: `**${durationLabel}**`, inline: true },
                { name: '👮 Created By', value: `<@${user.id}>`, inline: true }
            )
            .setFooter({ text: 'LumoHub • Premium Key' })
            .setTimestamp();

        return interaction.reply({ embeds: [embed], ephemeral: true });
    }

    // ── /testwelcome (Owner Only) ─────────────────────────────
    if (commandName === 'testwelcome') {
        if (!hasOwnerRole(member)) {
            return interaction.reply({ content: '❌ You do not have permission to use this command!', ephemeral: true });
        }

        try {
            const channel = interaction.guild.channels.cache.get(WELCOME_CHANNEL_ID);
            if (channel) {
                const welcomeEmbed = new EmbedBuilder()
                    .setTitle('✨ Welcome to LumoHub! ✨')
                    .setDescription(`Welcome to the server, ${interaction.member}! We're thrilled to have you here.\n\n🔑 Use the **/generate** command to get your 1-hour premium key and unlock our Roblox exploit suite!\n\n💬 Be sure to check out the server channels and enjoy your stay!\n\n📖 **Remember to read <#1510024611029581925> for important information!**`)
                    .setColor(0xFECC23) // LumoHub Golden Hex
                    .setThumbnail(interaction.user.displayAvatarURL({ forceStatic: true, size: 256 }))
                    .setFooter({ text: 'LumoHub Bot • Premium Exploiting' })
                    .setTimestamp();

                await channel.send({ content: `Welcome ${interaction.member}! (TEST MODE)`, embeds: [welcomeEmbed] });
                return interaction.reply({ content: `✅ Successfully sent a test welcome message to <#${WELCOME_CHANNEL_ID}>!`, ephemeral: true });
            } else {
                return interaction.reply({ content: `❌ Welcome channel with ID ${WELCOME_CHANNEL_ID} not found in this guild!`, ephemeral: true });
            }
        } catch (err) {
            console.error('[LumoHub] Test welcome failed:', err.message);
            return interaction.reply({ content: `❌ Failed to send test welcome message: ${err.message}`, ephemeral: true });
        }
    }

    // ── /poststatus (Owner Only) ──────────────────────────────
    if (commandName === 'poststatus') {
        if (!hasOwnerRole(member)) {
            return interaction.reply({ content: '❌ You do not have permission to use this command!', ephemeral: true });
        }

        const STATUS_CHANNEL_ID = '1509993493060128839';

        try {
            const channel = interaction.guild.channels.cache.get(STATUS_CHANNEL_ID);
            if (channel) {
                const statusEmbed = new EmbedBuilder()
                    .setTitle('📢 LumoHub | Official Game Status')
                    .setDescription('Current execution status of our supported Roblox scripts.')
                    .setColor(0xFECC23) // LumoHub gold color
                    .addFields(
                        { name: '🟢 Streetz War 2', value: '```Active & Working```', inline: false },
                        { name: '🔴 Blade Ball', value: '```Under Development```', inline: false },
                        { name: '⏳ Future Projects', value: '*More games coming soon...*', inline: false }
                    )
                    .setThumbnail(interaction.guild.iconURL({ dynamic: true, size: 256 }) || null)
                    .setFooter({ text: 'LumoHub • Premium Exploiting' })
                    .setTimestamp();

                await channel.send({ embeds: [statusEmbed] });
                return interaction.reply({ content: `✅ Successfully posted the status embed to <#${STATUS_CHANNEL_ID}>!`, ephemeral: true });
            } else {
                return interaction.reply({ content: `❌ Status channel with ID ${STATUS_CHANNEL_ID} not found in this guild!`, ephemeral: true });
            }
        } catch (err) {
            console.error('[LumoHub] Post status failed:', err.message);
            return interaction.reply({ content: `❌ Failed to send status message: ${err.message}`, ephemeral: true });
        }
    }

    // ── /setuptickets (Owner Only) ────────────────────────────
        if (commandName === 'setuptickets') {
            if (!hasOwnerRole(member)) {
                return interaction.reply({ content: '❌ You do not have permission to use this command!', ephemeral: true });
            }
            
            const embed = new EmbedBuilder()
                .setTitle('🎫 LumoHub Ticket Support')
                .setDescription('Please select the category for your ticket from the dropdown below to contact the team.')
                .setColor(0xFECC23);

            const row = new ActionRowBuilder()
                .addComponents(
                    new StringSelectMenuBuilder()
                        .setCustomId('ticket_category_select')
                        .setPlaceholder('Select a ticket category...')
                        .addOptions([
                            { label: 'Support', description: 'General support for LumoHub scripts', value: 'ticket_support', emoji: '🔧' },
                            { label: 'Content Creation', description: 'Apply to be a content creator', value: 'ticket_content', emoji: '🎥' },
                            { label: 'Bug Report', description: 'Report a bug or exploit issue', value: 'ticket_bug', emoji: '🐛' },
                            { label: 'Redeem Giveaway Prize', description: 'Claim a prize you won', value: 'ticket_giveaway', emoji: '🎁' }
                        ])
                );

            await interaction.channel.send({ embeds: [embed], components: [row] });
            return interaction.reply({ content: '✅ Ticket panel setup successfully!', ephemeral: true });
        }
    } else if (interaction.isStringSelectMenu()) {
        if (interaction.customId === 'ticket_category_select') {
            await interaction.deferReply({ ephemeral: true });
            
            const category = interaction.values[0];
            const guild = interaction.guild;
            const user = interaction.user;
            
            let channelName = `ticket-${user.username}`;
            let embedTitle = 'TICKET';
            let permissions = [
                {
                    id: guild.roles.everyone.id,
                    deny: [PermissionsBitField.Flags.ViewChannel],
                },
                {
                    id: user.id,
                    allow: [PermissionsBitField.Flags.ViewChannel, PermissionsBitField.Flags.SendMessages, PermissionsBitField.Flags.ReadMessageHistory],
                },
                {
                    id: OWNER_ROLE_ID,
                    allow: [PermissionsBitField.Flags.ViewChannel, PermissionsBitField.Flags.SendMessages, PermissionsBitField.Flags.ReadMessageHistory],
                }
            ];

            let pingContent = `<@${user.id}> | <@&${OWNER_ROLE_ID}>`;
            let embedDesc = `Welcome ${user}! The staff team (<@&${OWNER_ROLE_ID}>) will be with you shortly.\n\nPlease describe your issue or request in detail.`;

            if (category === 'ticket_support') { 
                channelName = `support-ticket-${user.username}`; 
                embedTitle = 'SUPPORT'; 
                permissions.push({
                    id: '1510000102650151052', // Support Role
                    allow: [PermissionsBitField.Flags.ViewChannel, PermissionsBitField.Flags.SendMessages, PermissionsBitField.Flags.ReadMessageHistory],
                });
                pingContent = `<@${user.id}> | <@&1510000102650151052>`;
                embedDesc = `Welcome ${user}! The support team (<@&1510000102650151052>) and admins will be with you shortly.\n\nPlease describe your issue or request in detail.`;
            }
            if (category === 'ticket_content') { channelName = `content-creation-${user.username}`; embedTitle = 'CONTENT CREATION'; }
            if (category === 'ticket_bug') { channelName = `bug-report-${user.username}`; embedTitle = 'BUG REPORT'; }
            if (category === 'ticket_giveaway') { channelName = `giveaway-prize-${user.username}`; embedTitle = 'GIVEAWAY PRIZE'; }
            
            try {
                const channel = await guild.channels.create({
                    name: channelName,
                    type: ChannelType.GuildText,
                    parent: '1510245034077851808',
                    permissionOverwrites: permissions,
                });

                const embed = new EmbedBuilder()
                    .setTitle(`🎫 ${embedTitle} TICKET`)
                    .setDescription(embedDesc)
                    .setColor(0xFECC23);

                const row = new ActionRowBuilder()
                    .addComponents(
                        new ButtonBuilder()
                            .setCustomId('close_ticket')
                            .setLabel('Close Ticket')
                            .setStyle(ButtonStyle.Danger)
                            .setEmoji('🔒')
                    );

                await channel.send({ content: pingContent, embeds: [embed], components: [row] });
                
                await interaction.editReply({ content: `✅ Your ticket has been created: <#${channel.id}>` });
            } catch (err) {
                console.error('[LumoHub] Ticket creation failed:', err);
                await interaction.editReply({ content: '❌ Failed to create ticket channel. Please contact an admin.' });
            }
        }
    } else if (interaction.isButton()) {
        if (interaction.customId === 'close_ticket') {
            const hasSupportRole = Array.isArray(interaction.member.roles) 
                ? interaction.member.roles.includes('1510000102650151052') 
                : interaction.member.roles.cache.has('1510000102650151052');
                
            if (!hasOwnerRole(interaction.member) && !hasSupportRole) {
                return interaction.reply({ content: '❌ Only staff can close tickets.', ephemeral: true });
            }
            await interaction.reply({ content: '🔒 Ticket will be closed and deleted in 5 seconds...' });
            setTimeout(() => {
                interaction.channel.delete().catch(err => console.error('Failed to delete ticket:', err));
            }, 5000);
        }
    }
});

client.on('messageCreate', async (message) => {
    // Ignore bot messages
    if (message.author.bot) return;

    // Strict channel for generate-key
    if (message.channel.id === '1509993539176759479') {
        try {
            await message.delete();
            try {
                await message.author.send(`🚫 Please do not chat in the <#1509993539176759479> channel!\n\nThis channel is strictly for generating keys. **To generate a free key, type the \`/generate\` command.**\n\nIf you want to chat or need support, please use the <#1509993379285696673> channel.`);
            } catch (dmErr) {
                // Ignore if DMs are closed
            }
        } catch (err) {
            console.error('[LumoHub] Failed to delete message in generate-key channel:', err);
        }
    }
});

// (Bot is now started inside the loadData().then() block near line 124)

process.on('unhandledRejection', error => {
    console.error('Unhandled promise rejection:', error);
});
