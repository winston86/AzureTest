#!/bin/bash

# ==========================================================
# FULL TASK RUNNER
# Виконує повний цикл: Terraform -> Генерація ENV/Map -> Ansible -> Верифікація
# ==========================================================

# А. Перевірка необхідних залежностей
echo "--- 1. Перевірка залежностей (terraform, jq, ansible) ---"
command -v terraform >/dev/null 2>&1 || { echo >&2 "Помилка: Terraform не знайдено."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo >&2 "Помилка: JQ не знайдено."; exit 1; }
command -v ansible-playbook >/dev/null 2>&1 || { echo >&2 "Помилка: Ansible не знайдено."; exit 1; }

# Перевірка наявності файлів Ansible
if [ ! -d "ansible" ] || [ ! -f "ansible/pbr_config.yml" ]; then
    echo >&2 "Помилка: Папка 'ansible/' або файл 'ansible/pbr_config.yml' відсутні."; exit 1;
fi

# ==========================================================
# Б. КРОК 1: РОЗГОРТАННЯ INFRASTRUCTURE (TERRAFORM)
# ==========================================================

echo ""
echo "--- 2. Розгортання інфраструктури Terraform ---"

terraform init -upgrade || { echo "Помилка Terraform Init. Спробуйте вручну: terraform init -upgrade"; exit 1; }
terraform apply -auto-approve || { echo "Помилка Terraform Apply."; exit 1; }

echo "Інфраструктура розгорнута успішно."

# ==========================================================
# В. КРОК 2: ГЕНЕРАЦІЯ IP MAP ТА ENV
# (Синтезовано з get_generated_env.sh)
# ==========================================================

echo ""
echo "--- 3. Генерація файлів ip_map.txt та .env ---"

# 3.1 Отримання даних з Terraform
PRIMARY_HOST=$(terraform output -raw primary_public_ip)
VM_USER=$(terraform output -raw vm_admin_username)
NIC_NAME=$(terraform output -raw nic_name)
PRIVATE_IPS_JSON=$(terraform output -json all_private_ips)
PUBLIC_IPS_JSON=$(terraform output -json all_public_ips)

if [ -z "$PRIMARY_HOST" ] || [ -z "$VM_USER" ]; then
    echo "Помилка: Не вдалося отримати критичні вихідні дані Terraform."
    exit 1
fi

# 3.2 Генерація ip_map.txt
PRIVATE_IPS=$(echo "$PRIVATE_IPS_JSON" | jq -r '.[]')
PUBLIC_IPS=$(echo "$PUBLIC_IPS_JSON" | jq -r '.[]')
IP_MAPPING=$(paste <(echo "$PRIVATE_IPS") <(echo "$PUBLIC_IPS") -d ':')
echo "$IP_MAPPING" > ip_map.txt
echo "Створено ip_map.txt"

# 3.3 Генерація .env
# Екранування JSON для безпечної передачі
ALL_PRIVATE_IPS_JSON_ESC=$(echo "$PRIVATE_IPS_JSON" | tr -d '\n' | sed 's/"/\\"/g')

cat << EOF > .env
# Ansible environment variables for dynamic inventory setup
ANSIBLE_HOST=$PRIMARY_HOST
ANSIBLE_USER=$VM_USER
NIC_NAME=$NIC_NAME
VM_PRIVATE_IPS_JSON="$ALL_PRIVATE_IPS_JSON_ESC"
EOF
echo "Створено .env"

# 3.4 Завантаження змінних
source .env
echo "Змінні .env завантажено в поточний Shell."

# ==========================================================
# Г. КРОК 3: КОНФІГУРАЦІЯ (ANSIBLE)
# ==========================================================

echo ""
echo "--- 4. Запуск Ansible Playbook для налаштування PBR ---"

ansible-playbook -i ./ansible/inventory.ini \
    --extra-vars "ansible_host=$ANSIBLE_HOST ansible_user=$ANSIBLE_USER vm_private_ips_json=$VM_PRIVATE_IPS_JSON nic_name=$NIC_NAME" \
    ./ansible/pbr_config.yml \
    --private-key ~/.ssh/id_rsa || { echo "Помилка Ansible Playbook."; exit 1; }

echo "Ansible Playbook виконано успішно. PBR налаштовано."

# ==========================================================
# Д. КРОК 4: ВЕРИФІКАЦІЯ (НА VM)
# ==========================================================

echo ""
echo "--- 5. Верифікація Policy-Based Routing (PBR) (Виконується через Ansible) ---"

# Ansible Playbook (Крок 4) вже містить верифікацію.
# Якщо Ansible завершився успішно, верифікація пройдена.

echo "Верифікація завершена. Перегляньте вивід Ansible Playbook для результатів."