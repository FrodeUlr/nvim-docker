# Add to docker container dockerfile:

nvim options:

if vim.fn.has("wsl") == 1 then
vim.g.clipboard = {
name = "win32yank-wsl",
copy = {
["+"] = "win32yank.exe -i --crlf",
["*"] = "win32yank.exe -i --crlf",
},
paste = {
["+"] = "win32yank.exe -o --lf",
["*"] = "win32yank.exe -o --lf",
},
cache_enabled = true,
}
end

git clone https://github.com/equalsraf/win32yank/releases/download/v0.1.1/win32yank-x64.zip

/etc/wsl.conf

[user]
default=ubuntu

.bashrc:

zsh
exit
