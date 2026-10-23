1|#!/bin/bash
2|# virgin-ize a demo box: remove llama, hermes, nvidia driver, install state. KEEP ~/models.
3|set -x
4|SUDO(){ sudo -p '[virgin] sudo password: ' bash -c "$*"; }
5|systemctl --user disable --now llama-vision-96k.service 2>/dev/null
6|SUDO "systemctl disable --now llama-vision-96k.service; rm -f /etc/systemd/system/llama-vision-96k.service; systemctl daemon-reload"
7|SUDO "apt-get purge -y 'nvidia-*' 'libnvidia-*' 'cuda-*' >/dev/null 2>&1; apt-get autoremove -y >/dev/null 2>&1"
8|rm -rf ~/llama-cuda ~/.hermes ~/.local/bin/hermes ~/.local/share/hermes* ~/install.log ~/INSTALL-PROMPT.txt ~/install-watch.sh ~/install.state ~/.install-pass ~/.install-mode ~/.install-think ~/.turnkey-llm* 2>/dev/null
9|rm -f ~/.config/systemd/user/llama-*.service ~/.config/systemd/user/hermes-gateway.service
10|rm -f ~/.config/systemd/user/default.target.wants/llama-*.service ~/.config/systemd/user/default.target.wants/hermes-gateway.service
11|systemctl --user daemon-reload 2>/dev/null
12|SUDO "rm -f /usr/local/bin/llama-mode; loginctl disable-linger $(id -un) 2>/dev/null; true"
13|sed -i '/turnkey-llm resume hook/,+1d' ~/.bashrc
14|command -v nvidia-smi && echo "DRIVER SURVIVED" || echo "DRIVER GONE"
15|ls ~/models
16|echo VIRGIN-READY