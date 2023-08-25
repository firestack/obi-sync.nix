# Rev Obsidian Sync

Reverse engineered obsidian sync server (NOT OFFICIAL)

> [!WARNING]
> This is an experimental proof of concept. It was written hastily without knowledge of the real internal mechanisms. Expect a thousand bugs and inefficiencies. This is an incomplete reproduction of the server. Many features aren't supported yet. I'm not responsible for any data loss or corruption. Use at your own risk.

> [!NOTE]
> If you have the time and energy, feel free to help out with PRs or suggestions.

## Features
- Basic sync
- File recovery
- File history

## To do
- Fix bugs
- Sharing notes
- Publish
- ~~Automate patching of electron app~~ Plugin to override API endpoint [#1](https://github.com/acheong08/rev-obsidian-sync/issues/1)

## Setup

- `git clone https://github.com/acheong08/obsidian-sync`
- `cd obsidian-sync`
- `export HOST=<YOUR DOMAIN NAME>`
- `go run cmd/obsidian-sync/main.go`
- Use nginx or cloudflare to proxy & handle TLS/SSL

### Nginx configuration
```nginx
map $http_upgrade $connection_upgrade {
        default upgrade;
        '' close;
}
server {
	listen 80 default_server;
	listen [::]:80 default_server;
	location / {
		proxy_http_version 1.1;
            	proxy_set_header Upgrade $http_upgrade;
            	proxy_set_header Connection $connection_upgrade;
           	proxy_set_header Host $host;
		proxy_pass http://127.0.0.1:3000/;
	}
	server_name _;
}
```

## Adding a new user

`go run cmd/signup/main.go`

## Usage

<details>

<summary>

> [!WARNING]
> Experimental!

Sync override plugin

</summary>

- Install https://github.com/acheong08/rev-obsidian-sync-plugin
- Go to settings
- Set API endpoint

</details>

As ObsidianMD is written with Electron, you can unzip the resource pack and modify it to suite your needs

- Download [Obsidian](https://github.com/obsidianmd/obsidian-releases/releases/)
- `tar -xvzf obsidian-1.3.7.tar.gz`
- `cd obsidian-1.3.7/resources`
- `npx asar extract obsidian.asar obsidian`
- `sed -i 's|api.obsidian.md|<YOUR DOMAIN NAME>|g' obsidian/*.js` (Remember to replace https with http if running on localhost)
- `npx asar pack obsidian obsidian.asar`
- Run the binary
