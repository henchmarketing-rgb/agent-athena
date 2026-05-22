// pm2 ecosystem config for Paperclip
// Usage: pm2 start ecosystem.config.js && pm2 save

module.exports = {
  apps: [{
    name: 'paperclip',
    script: './dist/server.js',
    cwd: process.env.HOME + '/Apps/paperclip',  // adjust if your paperclip path differs
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '500M',
    env: {
      NODE_ENV: 'production',
      // PORT must be set here explicitly.
      // If you run `paperclipai onboard` it starts a process on 3100 and leaves it.
      // pm2 will fail silently if port 3100 is already taken.
      // Always kill manual paperclip processes before running `pm2 start`.
      // Check: lsof -i :3100 | kill -9 [PID] if anything is there.
      PORT: '3100'
    }
  }]
}
