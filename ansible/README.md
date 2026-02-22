# Ansible Controller

## Installer les packages sur le bastion
sudo dnf makecache --refresh
sudo dnf install -y python3 python3-pip git vim

## Python virtualenv
```bash
# Installer le module python virtualenv
pip3 install --user virtualenv

# Créer l'environnement virtuel
python3 -m venv ~/.virtualenv/ansible

# Ajouter un alias au bashrc
echo 'monenv="source ~/.virtualenv/ansible/bin/activate"' >> ~/.bashrc
source ~/.bashrc
```