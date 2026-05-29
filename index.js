require('dotenv').config();
const { Client, GatewayIntentBits, REST, Routes, SlashCommandBuilder, EmbedBuilder } = require('discord.js');
const http = require('http');

const {
    DISCORD_TOKEN,
    CLIENT_ID,
    GUILD_ID,
    PORT = '3000'
} = process.env;

const ANNOUNCE_CHANNEL_ID = '1509993539176759479';
const COOLDOWN_MS = 60 * 60 * 1000; // 1 hour

// ── Key storage (in-memory) ───────────────────────────────────
const validKeys  = new Map(); // key => expiresAt
const userCooldown = new Map(); // userId => generatedAt

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
    for (const [key, exp] of validKeys.entries()) {
        if (exp < now) validKeys.delete(key);
    }
}

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
    console.log(`[LumoHub] Key endpoint: http://localhost:${PORT}/keys`);
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
    // Auto prune every 10 minutes
    setInterval(pruneExpired, 10 * 60 * 1000);
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

        // Generate and store immediately — no external API needed
        const key = generateKey();
        validKeys.set(key, now + COOLDOWN_MS);
        userCooldown.set(user.id, now);

        // Private reply with the key
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

        console.log(`[LumoHub] Key generated for ${user.username}: ${key}`);
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
        return interaction.reply({ content: '✅ Cooldown cleared. Use `/generate` for a new key.', ephemeral: true });
    }
});

registerCommands()
    .then(() => client.login(DISCORD_TOKEN))
    .catch(console.error);
