# YandexCloud-Practicum-Security-Course

Сценарий для развертывания контроллера домена IdP KeyCloak и рабочей станции.

Сценарий написан для курса "Настройка безопасной среды в Yandex.Cloud".

# Настройка окружения
Предполагаем, что приступая к выполнению заданий практикума у вас уже есть доступ в Yandex Cloud, вы знаете идентификатор своего облака (cloud-id) и [идентификатор каталога](https://cloud.yandex.ru/docs/resource-manager/operations/folder/get-id) (folder-id) в вашем облаке где в процессе выполнения заданий практикума будут создаваться облачные ресурсы.

## Установка YC CLI
Для развёртывания рабочего окружения установим инструмент `Yandex Cloud CLI (yc)` на свой компьютер [(подробная инструкция)](https://cloud.yandex.ru/docs/cli/operations/install-cli#interactive).
 
## Установка git
Для загрузки рецепта Terraform установите git [по инструкции](https://git-scm.com/book/ru/v2/Введение-Установка-Git).
 
## Установка Terraform
Установите инструмент `Terraform` на свой компьютер (если он уже не установлен) по [(инструкции)](https://cloud.yandex.ru/docs/tutorials/infrastructure-management/terraform-quickstart#install-terraform).

  ### Установка Terraform для Windows:
  Распакуйте архив и скопируйте файл terraform.exe в каталог `C:\Windows\System32`
 
Для корректной установки всех необходимых ресурсов Terraform создайте в домашнем каталоге (`/home/<username>` - для MacOS и Linux, `C:\Users\Administrator\AppData\Roaming`- для Windows) файл `.terraformrc` (для Windows `terraform.rc`) с содержимым:

```bash
provider_installation {
    network_mirror {
      url = "https://terraform-mirror.yandexcloud.net/"
      include = ["registry.terraform.io/*/*"]
    }
    direct {
      exclude = ["registry.terraform.io/*/*"]
    }
  }
  ```
 
 
## Подключение к Web консоли облака с помощью Яндекс ID
* Откроем в новой вкладке браузера [консоль облака](https://console.cloud.yandex.ru/) и, слева внизу, выберем `Учетная запись` и выйдем из всех текущих аккаунтов облака. В результате на экране должна показаться страница с кнопкой `Войти в аккаунт на Яндексе`. Закроем эту страницу.
* Откроем в новой вкладке [ссылку](https://passport.yandex.ru/auth?mode=add-user&retpath=https%3A%2F%2Fconsole.cloud.yandex.ru%2F) где будет предложено авторизоваться в Яндекс ID
* Введём имя и пароль пользователя для учётной записи Яндекс ID, после чего произойдёт перенаправление в консоль Yandex Cloud
* Перейдём по [ссылке](https://oauth.yandex.ru/authorize?response_type=token&client_id=1a6990aa636648e9b2ef855fa7bec2fb) для получения OAuth Token. Значение token будет выглядеть примерно так `AQAAAAAABQ0pAATrwPdubkJPerC4mJyaRELWbUY`
* Сохраним полученное значение Token в переменной окружения (для Windows – PowerShell, MacOS и Linux – bash)

#### Windows:
```PowerShell
$env:YC_TOKEN="<ваш OAuth Token>"
```

#### MacOS и Linux:
```bash
export YC_TOKEN=<ваш OAuth Token>
```


Создадим профиль в yc для работы с облаком

#### Настройка профиля yc в MacOS и Linux:
```bash
yc config profile create security
yc config set cloud-id <cloud-id>
yc config set folder-id <folder-id>
yc config set token $YC_TOKEN
```

#### Настройка профиля yc в Windows:
```PowerShell
yc config profile create security
yc config set cloud-id <cloud-id>
yc config set folder-id <folder-id>
yc config set token $env:YC_TOKEN
```

где вместо `<cloud-id>` нужно указать идентификатор своего облака, а вместо `<folder-id>` нужно указать идентификатор каталога в облаке. Идентификаторы можно получить из консоли облака через веб интерфейс.
 
### Загрузка сценария Terraform
```bash
git clone https://github.com/Sayanaro/YandexCloud-Security-Course-KeyCloackVersion.git
cd YandexCloud-Security-Course-KeyCloackVersion
```
 
## Развёртывание рабочей среды с помощью Terraform
Сценарий разворачивает контроллер домена Active Directory + ADFS, рабочую станцию ws и инстанс интернет-магазина OpenCart.

Имена виртуальных машин, домена, и пользователей задаются переменными в файле `terraform.tfvars`. Остальные переменные заданы в файле `variables.tf` в параметрах по умолчанию.

Для начала зададим переменные окружения:
 
#### Windows:
 
* Запустите консоль PowerShell
* Выполните:
```PowerShell
yc config profile activate security
$env:YC_TOKEN = "ваш OAuth токен"
$env:YC_CLOUD_ID=$(yc config get cloud-id)
$env:YC_FOLDER_ID=$(yc config get folder-id)
```
 
#### MacOS/Linux:
 
* Запустите консоль bash
* Выполните:
```bash
yc config profile activate security
export YC_TOKEN="ваш OAuth токен"
export YC_CLOUD_ID=$(yc config get cloud-id)
export YC_FOLDER_ID=$(yc config get folder-id)
```
 
Инициализируйте Terraform:
```bash
terraform init
terraform apply
```

Сценарий попросит ввести пароль администратора. Пароль должен быть не менее 8 символов, содержать строчные и заглавные буквы, минимум одну цифру 0-9 и минимум один спецсимвол (@#$%&*/:;"'\,.?+=-_).

Спустя 25 минут окружение будет настроено и готово к работе.

Дальнейшая работа будет проводиться на ВМ ws для демонстрации создания федерации.

### Подключение к ВМ из Windows:
Перед созданием ВМ терраформ генерирует криптопару для доступа к гостевой ОС по протоколу SSH. Закрытый ключ сохраняется в файле `pt_key.pem`. Чтобы подключиться с использованием этого файла из ОС Windows необходимо изменить права доступа к нему.
После выполнения сценария Terraform выполните в PowerShell:

```PowerShell
$Key = "pt_key.pem"
Icacls $Key /c /t /Inheritance:d
Icacls $Key /c /t /Remove:g Administrator "Authenticated Users" BUILTIN\Administrators BUILTIN Everyone System Users
Icacls $Key /c /t /Grant ${env:UserName}:F
TakeOwn /F $Key
Icacls $Key /c /t /Grant:r ${env:UserName}:F
Icacls $Key
```

После этого можно подключаться к ВМ Linux по ssh:

```PowerShell
ssh <username>@<pulic_ip> -i pt_key.pem
```

## Подключение к ВМ
```bash
# keycloak:
ssh ubuntu@<keycloak_vm_public_ip> -i pt_key.pem

# ws:
ssh sles@<ws_vm_public_ip> -i pt_key.pem
```

Для полдключения к рабочему столу через VNC-клиент: 
* подключитесь к ВМ ws по ssh:
```bash
ssh sles@<ws_vm_public_ip> -i pt_key.pem
```
* выполните:
```bash
vncserver -geometry 1200x800 -depth 32 -name remote-desktop :1
```
* Подключитесь к рабочему столу по порту 5901