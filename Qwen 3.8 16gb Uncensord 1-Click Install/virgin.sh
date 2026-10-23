#!/bin/bash
# virgin-ize a demo box: remove llama, hermes, nvidia driver, install state. KEEP ~/models.
set -x
SUDO(){ sudo -p '[virgin] sudo password: ' bash -c "$*"; }
systemctl --user disable --now llama-vision-96k.service 2>/dev/null
SUDO "systemctl disable --now llama-vision-96k.service; rm -f /etc/systemd/system/llama-vision-96k.service; systemctl daemon-reload"
SUDO "apt-get purge -y 'nvidia-*' 'libnvidia-*' 'cuda-*' >/dev/null 2>&1; apt-get autoremove -y >/dev/null 2>&1"
rm -rf ~/llama-cuda ~/.hermes ~/.local/bin/hermes ~/.local/share/hermes* ~/install.log ~/INSTALL-PROMPT.txt ~/install-watch.sh ~/install.state ~/.install-pass ~/.install-mode ~/.install-think ~/.turnkey-llm* 2>/dev/null
rm -f ~/.config/systemd/user/llama-*.service ~/.config/systemd/user/hermes-gateway.service
rm -f ~/.config/systemd/user/default.target.wants/llama-*.service ~/.config/systemd/user/default.target.wants/hermes-gateway.service
systemctl --user daemon-reload 2>/dev/null
SUDO "rm -f /usr/local/bin/llama-mode; loginctl disable-linger $(id -un) 2>/dev/null; true"
sed -i '/turnkey-llm resume hook/,+1d' ~/.bashrc
command -v nvidia-smi && echo "DRIVER SURVIVED" || echo "DRIVER GONE"
ls ~/models
echo VIRGIN-READY
