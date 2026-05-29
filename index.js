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
const COOLDOWN_MS = 60 * 60 * 1000; // 1 hour

// ── Persistent File Paths ─────────────────────────────────────
const KEYS_FILE = path.join(__dirname, 'keys.json');
const COOLDOWNS_FILE = path.join(__dirname, 'cooldowns.json');

// ── Key storage maps ──────────────────────────────────────────
let validKeys = new Map();
let userCooldown = new Map();

// Load data from disk if it exists
function loadData() {
    try {
        if (fs.existsSync(KEYS_FILE)) {
            const data = JSON.parse(fs.readFileSync(KEYS_FILE, 'utf8'));
            validKeys = new Map(Object.entries(data));
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
    const m = Math.floor(ms / 60000);
    const s = Math.floor((ms % 60000) / 1000);
    return `${m}m ${s}s`;
}

function pruneExpired() {
    const now = Date.now();
    let changed = false;
    for (const [key, exp] of validKeys.entries()) {
        if (exp < now) {
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
        .setDescription('Check how long your key has remaining')
        .toJSON(),
    new SlashCommandBuilder()
        .setName('revoke')
        .setDescription('Clear your cooldown to get a new key')
        .toJSON()
];

const rest = new REST({ version: '10' }).setToken(DISCORD_TOKEN);

async function registerCommands() {
    await rest.put(Routes.applicationGuildCommands(CLIENT_ID, GUILD_ID), { body: commands });
    console.log('[LumoHub] Slash commands registered.');
}

// ── Discord client ────────────────────────────────────────────
const client = new Client({ intents: [GatewayIntentBits.Guilds] });

client.once('clientReady', () => {
    console.log(`[LumoHub] Logged in as ${client.user.tag}`);
    client.user.setActivity('LumoHub | /generate');
    setInterval(pruneExpired, 5 * 60 * 1000);
});

client.on('interactionCreate', async interaction => {
    if (!interaction.isChatInputCommand()) return;

    const { commandName, user, guildId } = interaction;

    if (guildId !== GUILD_ID) {
        return interaction.reply({ content: '❌ Use this in the **LumoHub** server!', ephemeral: true });
    }

    // ── /generate ─────────────────────────────────────────────
    if (commandName === 'generate') {
        const now = Date.now();
        const lastGen = userCooldown.get(user.id);

        if (lastGen && now - lastGen < COOLDOWN_MS) {
            const remaining = COOLDOWN_MS - (now - lastGen);
            return interaction.reply({
                content: `⏳ You already have an active key!\nTry again in **${formatCountdown(remaining)}**.`,
                ephemeral: true
            });
        }

        const key = generateKey();
        validKeys.set(key, now + COOLDOWN_MS);
        userCooldown.set(user.id, now);
        saveData(); // Persist changes immediately

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
        const lastGen = userCooldown.get(user.id);
        if (!lastGen) return interaction.reply({ content: '❌ No active key. Use `/generate`!', ephemeral: true });
        const remaining = (lastGen + COOLDOWN_MS) - Date.now();
        if (remaining <= 0) return interaction.reply({ content: '⌛ Key **expired**. Use `/generate`!', ephemeral: true });

        const embed = new EmbedBuilder()
            .setColor(0x7c3aed)
            .setTitle('⏳ Key Status')
            .setDescription(`Expires in **${formatCountdown(remaining)}**.`)
            .setFooter({ text: 'LumoHub • discord.gg/KeJDfYV4QR' });

        return interaction.reply({ embeds: [embed], ephemeral: true });
    }

    // ── /revoke ───────────────────────────────────────────────
    if (commandName === 'revoke') {
        userCooldown.delete(user.id);
        saveData();
        return interaction.reply({ content: '✅ Cooldown cleared. Use `/generate` for a new key.', ephemeral: true });
    }
});

registerCommands()
    .then(() => client.login(DISCORD_TOKEN))
    .catch(console.error);
