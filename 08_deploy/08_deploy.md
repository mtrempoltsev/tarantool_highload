# Deploy

В прошлый раз мы изучили Tarantool Cartridge - фреймворк для написания распределенных приложений.
И вот мы разработали свое приложение и возник вопрос - как доставить приложение на продакшн?
Как настроить топологию на кластере, где 100 и больше инстансов?
Самое простое решение это вручную копировать файлы, переподнимать инстансы и нажимать кнопки в Web UI для управления топологией.

Но такой подход не для нас. Будем автоматизировать.

## Пакуем приложение

Итак, мы создали наше первое приложение на Tarantool Cartridge.
Для этого мы использовали утилиту Cartridge CLI:

```bash
$ cartridge create --name myapp
   • Create application myapp
   • Generate application files
   • Initialize application git repository
   • Application "myapp" created successfully
```

И теперь мы хотим отправить все это на несколько серверов, запустить пару десятков инстансов и собрать их в репликасеты.
Посмотрим внимательно на наше приложение:

```bash
├── Dockerfile.build.cartridge
├── Dockerfile.cartridge
├── README.md
├── app
│   ├── admin.lua
│   └── roles
│       └── custom.lua
├── cartridge.post-build
├── cartridge.pre-build
├── deps.sh
├── init.lua
├── instances.yml
├── myapp-scm-1.rockspec
├── replicasets.yml
├── stateboard.init.lua
├── test/
└── tmp/
```

Точкой входа (entry point) приложения является файл `init.lua`.
В нем происходит импорт модуля `cartridge` и вызов `cartridge.cfg` (и несколько других полезных вещей, которые сейчас не имеют значения).
В `cartridge.cfg` мы передаем список ролей, которые использует приложение и дефолтные значения для различных параметров (об этом позже поговорим подробнее).

Мы собираемся запустить несколько инстансов (instance, экземпляр), т.е. процессов нашего приложения.
Все они используют одну и ту же точку входа, но запускаются с разными параметрами.
Например, бинарный порт, http порт, да и само имя инстанса.

То есть для запуска инстансов нам необходимо:

* доставить на сервер собранное приложение;
* запустить кучу процессов и передать каждому из них свои параметры.

### Собранное приложение? Что это?

По сути, собранное приложение это то, что можно просто запустить.
Для того чтобы запустился наш `init.lua`, необходимо, чтобы были установлены все rock-модули, которые там используются.
Кроме этого, мы будем использовать роли, описанные в папке `app/roles`, и прочие дополнительные модули, которые есть в `app`.

Для локальной сборки приложения используем `cartridge build`:

```bash
$ cartridge build
   • Build application in /Users/e.dokshina/work/tarantool_highload/myapp
   • Running `cartridge.pre-build`
   • Running `tarantoolctl rocks make`
   • Application was successfully built
```

После этого в нашей директории появилась папочка `.rocks`, которая содержит внешние модули (вроде `cartridge` или `metrics`), которые необходимы нашему приложению.
Все они описаны в спеке `myapp-scm-1.rockspec`.

Итак, для успешного старта нам нужно просто взять собранное приложение, упаковать его в архив и распаковать на конечном сервере.

### RPM-пакеты

**RPM (Red Hat Packages Manager)** - менеджер пакетов в Red Hat подобных системах.
Он упрощает работу с установкой и управлением пакетами программ.
Формат пакетов, с которыми работает этот менеджер, называется так же - **RPM**.

По сути RPM-пакет это такой "умный" архив.
Он содержит в себе файлы приложения и дополнительную информацию о пакете, которая необходима для того чтобы корректно установить пакет в систему:

* имя, версия, ченджлог, саммари, URL и тд;
* зависимости;
* инструкции по сборке и установке пакета.

Один из плюсов использования RPM-пакетов это то что все установленные файлы находятся под контролем пакетного менеджера и будут удалены вместе с пакетом при его удалении.

Один из способов собрать RPM-пакет - это написать `.spec` файл с желаемой конфигурацией пакета и воспользоваться утилитой `rpmbuild` для сборки.

```
Name:           myapp
Version:        0.1.0
Release:        1%{?dist}
Summary:        Tarantool Cartridge application

Requires:       tarantool >= 2.8.0
Requires:       tarantool < 3

BuildArch:      noarch

%description
The long-tail description for our Tarantool Cartridge application

%files
%license LICENSE
%dir /usr/share/tarantool/%{name}/

...
```

Мы поступим несколько проще.
Воспользуемся командой `cartridge pack`.
Она соберет нам RPM-пакет для приложения следующим образом:

* скопирует файлы проекта во временную директорию (чтобы не испортить текущую папку);
* выполнит `cartridge.pre-build` файл, где может быть описана установка дополнительных зависимостей;
* запустит `tarantoolctl rocks make`, чтобы подтянуть зависимости из рокспеки;
* запустит `cartridge.post-build`, чтобы подчистить лишние файлы, которые мы не хотим тащить с собой на прод (например, `node_modules`).

В случае OS X так просто собрать проект не получится - установленные нами rock-модули могут содержать system-dependent файлы, которые мы не сможем потом запустить на Linux.
Не беда, Cartridge CLI умеет производить сборку в докер-контейнере.
Для этого достаточно указать дополнительный флажок `--use-docker`.
Если нужно просмотреть полные логи сборки, можно передать еще флаг `--verbose`.

```bash
cartridge pack rpm --use-docker
   • Packing myapp into rpm
   • Temporary directory is set to /Users/e.dokshina/.cartridge/tmp/pack-7z0sj50w03
   • Initialize application dir
   • Build application in /Users/e.dokshina/.cartridge/tmp/pack-7z0sj50w03/package-files/usr/share/tarantool/myapp
   • Building base image myapp-build
   • Build application in myapp-build
   • Remove container...
   • Application was successfully built
   • Running `cartridge.post-build`
   • Generate VERSION file
   • Initialize systemd dir
   • Initialize tmpfiles dir
   • Created result RPM package: /Users/e.dokshina/work/tarantool_highload/myapp/myapp-0.1.0-0-gb716d59.rpm
   • Application was successfully packed
```

В корне проекта у нас появился файл `myapp-0.1.0-0-gb716d59.rpm`.
Посмотрим, что у него внутри.

### Структура RPM-пакета Tarantool Cartridge-based приложения

Для просмотра информации об rpm-пакете можно воспользоваться утилитой `rpm`.
Можно установить ее локально, а можно поднять виртуалку из папки [practice](./practice), скопировать туда пакет и проделать все действия там:

```bash
vagrant up vm1
vagrant scp ./myapp-0.1.0-0-gb716d59.rpm vm1:/tmp
vagrant ssh vm1
[vagrant@localhost ~]$ cd tmp
```

Запросим общую информацию о пакете:

```bash
$ rpm -qip myapp-0.1.0-0-gb716d59.rpm
Name        : myapp
Version     : 0.1.0
Release     : 0-gb716d59
Architecture: x86_64
Install Date: (not installed)
Group       : None
Size        : 21899776
License     : N/A
Signature   : (none)
Source RPM  : (none)
Build Date  : (none)
Build Host  : (none)
Relocations : (not relocatable)
Summary     :
Description :
```

Попробуем установить пакет (используем пакетный менеджер `yum`):

```bash
sudo yum install -y myapp-0.1.0-0-gb716d59.rpm
```

Получим ошибку:

```
Error: Package: myapp-0.1.0-0-gb716d59.x86_64 (/myapp-0.1.0-0-gb716d59)
           Requires: tarantool < 3
Error: Package: myapp-0.1.0-0-gb716d59.x86_64 (/myapp-0.1.0-0-gb716d59)
           Requires: tarantool >= 2.8.0
 You could try using --skip-broken to work around the problem
```

`yum` попытался установить Tarantool, который указан в зависимостях у пакета, но не смог.
Подключим репозиторий Tarantool:

```bash
curl -L https://tarantool.io/jYuDdOV/release/2.8/installer.sh | bash
```

Версия `2.8` указана потому что локально установлен Tarantool 2.8, он же и прописан в dependencies у пакета.

Пробуем еще раз:

```bash
sudo yum install -y myapp-0.1.0-0-gb716d59.rpm
```

и на этот раз успешно.

Что появилось на сервере после установки пакета?

* файлы `/etc/systemd/system/myapp.service` и `/etc/systemd/system/myapp@.service` - systemd-юнит файлы для запуска инстансов приложения (к ним вернемся чуть позже);
* `/usr/lib/tmpfiles.d/myapp.conf` - конфигурация `tmpfiles`, описывает, какие временные директории системе необходимо пересоздавать после рестарта.
* `/usr/share/tarantool/myapp/` - здесь лежит наше собранное приложение;
* `/var/lib/tarantool/` - директория, где будут лежать working directories наших инстансов;
* `/var/run/tarantool/` - тут будут храниться PID-файлы и сокеты инстансов;
* `/etc/tarantool/conf.d/` - а вот сюда положим файлы с конфигурацией наших инстансов.

Настало время запускать наши инстансы.
Но для начала разберемся, как их конфигурировать

### Конфигурация инстансов приложения

У `cartridge` есть встроенный модуль `cartridge.argparse`.
Он умеет парсить параметры, которые можно передать инстансу различными способами.
В порядке приоритета:

1. аргументы командной строки при запуске: `--param`;
2. переменные окружения: `TARANTOOL_PARAM`
3. конфигурационные файлы;
4. параметры `cartridge.cfg`.

Мы будем использовать комбинацию переменных окружения и конфигурационных файлов.

Cartridge умеет считывать конфигурацию инстансов из `yaml`-файлов.
Можно передать как путь к одному файлу, так и путь к директории с множеством таких файлов.
Формат следующий:

```yaml
myapp:
  some_option: "application-specific value"

myapp.router:
  some_option: "router instance specific value"

default:
  some_option: "default value"
```

Сконфигурируем несколько простых инстансов.
Положим в папку `/etc/tarantool/conf.d` следующие конфигурационные файлы:

```yaml
# myapp.yml
myapp:
  cluster_cookie: secret-cookie
```

```yaml
# myapp.router.yml
myapp.router:
  advertise_uri: 172.19.0.2:3301
  http_port: 8181
```

```yaml
# myapp.storage.yml
myapp.storage:
  advertise_uri: 172.19.0.2:3302
  http_port: 8182
```

Для того чтобы считать такую конфигурацию, процессу необходимо знать имя приложения, имя конкретного инстанса и путь к директории с конфигурационными файлами.

Передавать их каждому инстансу мы будем при старте.
Сначала разберемся, как будут стартовать инстансы.

### Запускаем systemd-юниты

Будем использовать **`systemd`** - систему управления сервисами в Linux.
`systemd` оперирует юнитами, которые описываются в специальных файлах.

Вместе с RPM-пакетом мы установили systemd-unit файлы `myapp@.service`, `myapp-stateboard.service` и `myapp.service`.
Рассмотрим `myapp@.service`:

```conf
[Unit]
Description=Tarantool Cartridge app myapp@%i
After=network.target

[Service]
Type=simple
ExecStartPre=/bin/sh -c 'mkdir -p /var/lib/tarantool/myapp.%i'
ExecStart=/usr/bin/tarantool /usr/share/tarantool/myapp/init.lua
Restart=on-failure
RestartSec=2
User=tarantool
Group=tarantool

Environment=TARANTOOL_APP_NAME=myapp
Environment=TARANTOOL_WORKDIR=/var/lib/tarantool/myapp.%i
Environment=TARANTOOL_CFG=/etc/tarantool/conf.d
Environment=TARANTOOL_PID_FILE=/var/run/tarantool/myapp.%i.pid
Environment=TARANTOOL_CONSOLE_SOCK=/var/run/tarantool/myapp.%i.control
Environment=TARANTOOL_INSTANCE_NAME=%i

LimitCORE=infinity
# Disable OOM killer
OOMScoreAdjust=-1000
# Increase fd limit for Vinyl
LimitNOFILE=65535

# Systemd waits until all xlogs are recovered
TimeoutStartSec=86400s
# Give a reasonable amount of time to close xlogs
TimeoutStopSec=10s

[Install]
WantedBy=multi-user.target
Alias=myapp.%i
```

Такие файлы называются instantiated unit-файлы.
Они подразумевают, что мы будем запускать несколько инстансов одного приложения.
Здесь содержится информация о запускаемом процессе и инструкции по запуску (`ExecStartPre`, `ExecStart`).

Запуск происходит таким образом:

```bash
sudo systemctl start myapp@instance-name
```

* `myapp` - имя юнита (и нашего приложения);
* `instance-name` - имя инстанса.

При запуске переданное имя инстанса проставляется на место `%i` в файле.

Обратите внимание на директивы `Environment`.
Они передают недостающие параметры для каждого инстанса:

* `TARANTOOL_APP_NAME` - имя приложения;
* `TARANTOOL_INSTANCE_NAME` - имя инстанса;
* `TARANTOOL_CFG` - путь к директории с конфигурационными файлами.

Кроме того, для каждого инстанса тут указаны стандартные пути:

* `TARANTOOL_WORKDIR` (`/var/lib/tarantool/<app-name>.<instance-name>`) - путь к working directory инстанса, где хранятся снапшоты и WAL логи;
* `TARANTOOL_PID_FILE` (`/var/run/tarantool/<app-name>.<instance-name>.pid`) - путь к PID-файлу инстанса;
* `TARANTOOL_CONSOLE_SOCK` (`/var/run/tarantool/<app-name>.<instance-name>.control`) - путь к UNIX-сокету инстанса.

Обратите внимание, что параметры, переданные через environment, имеют больший приоритет, чем переменные, прописанные в конфигурационных файлах.

Итак, при запуске инстанса при помощи `systemctl`:

* вычисляются параметры, прописанные в systemd-unit файле;
* эти параметры передаются инстансу при старте через environment;
* используя `cfg`, `app_name` и `instance_name` параметры инстанс находит путь к конфигурационным файлам и считывает нужную секцию;
* инстанс стартует с нужными параметрами.

Запускаем наши инстансы и проверяем их статус:

```bash
sudo systemctl start myapp@router
sudo systemctl start myapp@router

sudo systemctl status myapp@*
```

Заглянем в Web UI http://localhost:8181/.

Вот мы и запустили 2 инстанса на одном сервере.
Осталось всего ничего - повторить все вышесказанные действия на втором сервере и запустить остальные инстансы.
Чтобы не совершать все манипуляции ручками, такие процессы обычно автоматизируют.

Давайте автоматизируем деплой.

## Ansible

**Ansible** - это средство автоматизации, которое позволяет настраивать узлы инфраструктуры.

Смысл следующий - вы описываете желаемую конфигурацию узлов (hosts) в плейбуках (playbooks), а Ansible приводит систему к заданному состоянию.
При этом плейбуки обладают свойством идемпотентности - при повторном выполнении результат не изменится.
Ansible задумывался как очень простое решение, для его использования необходимо понимание языка python и языка разметки YAML.

Как это работает?

### Playbook

* Плейбук представляет собой последовательность **плеев (plays)**.
* Каждый play состоит из **тасок (tasks)**.
* Каждая задача представляет собой вызов **модуля**.

Пример плейбука:

```yml
---
# first play
- name: update web servers  # play name
  hosts: webservers  # hosts to run play for
  remote_user: root

  tasks:
  - name: ensure apache is at the latest version
    yum:  # call `yum` module
      name: httpd
      state: latest  # ensure that `httpd` package state is `latest`
  - name: write the apache config file
    template:  # call `template` module
      src: /srv/httpd.j2
      dest: /etc/httpd.conf  # make dest file content equal to template

# second play
- name: update db servers  # play name
  hosts: databases  # hosts to run play for
  remote_user: root

  tasks:
  - name: ensure postgresql is at the latest version
    yum:  # call `yum` module
      name: postgresql
      state: latest  # ensure that `postgresql` package state is `latest`
  - name: ensure that postgresql is started
    service:  # call `service` module
      name: postgresql
      state: started  # ensure that `postgresql` service state is `started`
```

Для play можно указать [множество опций](https://docs.ansible.com/ansible/latest/reference_appendices/playbooks_keywords.html#playbook-keywords),
рассмотрим некоторые из них:

- `connection` - плагин, который нужно использовать для соединения с хостами (например, `ssh`, `local`, `docker`);
- `gather_facts` - нужно ли собрать информацию о системе, где располагаются настраиваемые узлы;
- `hosts` - для каких узлов (или групп узлов) нужно выполнить play;
- `tasks` - список тасок для запуска;
- `vars` - переменные, общие для всего play.

У `task` тоже есть [опции](https://docs.ansible.com/ansible/latest/reference_appendices/playbooks_keywords.html#task), например:

- `name` - имя таски, будет выведено в логах;
- `vars` - переменные;
- `any_errors_fatal` - падение таски для одного из узлов останавливает выполнение всего playbook;
- `delegate_to` - узел, которому нужно делегировать выполнение task;
- `loop` - позволяет выполнять task в цикле;
- `run_once` - выполнить таску для одного из узлов, результат выполнения будет расшарен между всеми узлами;
- `retries` + `until` - выполнять таску в цикле заданное количество раз, пока не будет достигнуто условие;
- `when` - условие, которое определяет, должны ли мы запускать task.

### Inventory

Чтобы описать, какие узлы инфраструктуры должны быть настроены, используется инвентарь (inventory).
Тут можно задать узлы, объединить их в группы и задать конфигурационные переменные, которые будем использовать в своих плейбуках.

Обычно это файл `hosts`.
Поддерживаются форматы INI и YAML, мы будем использовать YAML.

```ini
# hosts example
mail.example.com

[webservers]
foo.example.com
bar.example.com

[dbservers]
one.example.com
two.example.com
three.example.com
```

```yaml
# hosts.yml example
all:
  hosts:
    mail.example.com:
  children:
    webservers:
      hosts:
        foo.example.com:
        bar.example.com:
    dbservers:
      hosts:
        one.example.com:
        two.example.com:
        three.example.com:
```

Структура ивентори следующая:

* Все узлы принадлежат группе `all`, с нее и начинается инвентори.
* Группа может содержать следующие ключи:
  * `vars` - переменные, общие для узлов этой группы;
  * `hosts` - узлы, принадлежащие группе;
  * `children` - подгруппы данной группы.


В примере выше у нас есть 2 группы - `webservers` и `dbservers`, каждой из них принадлежит несколько узлов.
Также есть узел `mail.example.com`, принадлежащий только группе `all`.

Для чего полезно использовать группы?
Для того, чтобы передать переменные, общие для нескольких узлов.
Причем какие-то переменные могут быть переопределены для конкретных узлов или в подгруппах.

Рассмотрим следующий инвентарь:

```yaml
# hosts.test.yml
---
all:
  vars:
    colour: common-colour
  hosts:
    instance_common:
    instance_blue_1:
    instance_blue_2:
    instance_fake_blue:
    instance_red_1:
    instance_with_own_colour:
      colour: my-own-colour
  children:
    blue:
      hosts:
        instance_blue_1:
        instance_blue_2:
        instance_fake_blue:
          colour: yellow-colour
      vars:
        colour: blue-colour

    red:
      hosts:
        instance_red_1:
      vars:
        colour: red-colour
```

Чтобы проверить, какие переменные будут присвоены каждому инстансу, воспользуемся командой `ansible-inventory`, чтобы "вывернуть" инвентарь:

```bash
$ ansible-inventory -i hosts.test.yml --list
{
    "_meta": {
        "hostvars": {
            "instance_blue_1": {
                "colour": "blue-colour"
            },
            "instance_blue_2": {
                "colour": "blue-colour"
            },
            "instance_common": {
                "colour": "common-colour"
            },
            "instance_fake_blue": {
                "colour": "yellow-colour"
            },
            "instance_red_1": {
                "colour": "red-colour"
            },
            "instance_with_own_colour": {
                "colour": "my-own-colour"
            }
        }
    },
    "all": {
        "children": [
            "blue",
            "red",
            "ungrouped"
        ]
    },
    "blue": {
        "hosts": [
            "instance_blue_1",
            "instance_blue_2",
            "instance_fake_blue"
        ]
    },
    "red": {
        "hosts": [
            "instance_red_1"
        ]
    },
    "ungrouped": {
        "hosts": [
            "instance_common",
            "instance_with_own_colour"
        ]
    }
}
```

### Roles

Роль это механизм переиспользования tasks, переменных и хендлеров.
Она позволяет использовать единожды написанные механизмы для различных целей.

Как использовать роль?
Просто указать в play, какие роли нужно использовать:

```yaml
---
- hosts: webservers
  roles:
     - common
     - webservers
```

Готовые роли можно импортить из Ansible Galaxу или подключать подмодулями.

## Ansible-роль Tarantool Cartridge

Для управления Tarantool Cartridge существует специальная Ansible-роль [`tarantool.cartridge`](https://github.com/tarantool/ansible-cartridge).

Она позволяет делать все необходимое (ну или почти все) для управления большим кластером:

* устанавливать пакеты и подтягивать для них нужный репозиторий Tarantool;
* раскладывать конфигурационные файлы инстансов;
* стартовать `systemd`-сервисы инстансов;
* управлять топологией кластера;
* конфигурировать авторизацию;
* загружать конфигурацию приложения;
* конфигурировать failover и стартовать инстанс stateboard (внешнего хранилища конфигурации);

Желаемое состояние кластера мы будем описывать в inventory.
В терминах Ansible каждый инстанс кластера это узел инфраструктуры, с которым мы будем работать.
Такой подход позволяет управлять инстансами в отдельности, например переподнимать их в определенном порядке или использовать механизм `serial`, чтобы запускать плейбуки на инстансах небольшими "пачками".

### Описываем кластер

Начнем описание кластера.

* В группе `all` укажем общие параметры для всех инстансов - имя приложения, кластер куку и путь к пакету нашего приложения.
* Добавим несколько инстансов в `hosts`.

```yaml
---
all:
  vars:
    cartridge_app_name: myapp
    cartridge_cluster_cookie: secret-cookie
    cartridge_package_path: ./myapp-1.0.0-0.rpm

  hosts:
    storage-1-leader:
    storage-1-replica:
```

Для каждого инстанса нам необходимо указать конфигурацию в переменной `config`.
Минимальная конфигурация инстанса - это `advertise_uri`.

```yaml
---
all:
  vars:
    cartridge_app_name: myapp
    cartridge_cluster_cookie: secret-cookie
    cartridge_package_path: ./myapp-1.0.0-0.rpm

  hosts:
    storage-1-leader:
      config:
        advertise_uri: '172.19.0.2:3301'

    storage-1-replica:
      config:
        advertise_uri: '172.19.0.2:3302'
```

Теперь укажем для каждого инстанса параметры соединения.
Для этого объединим их в группу `machine_1` и укажем там общие опции.

```yaml
---
all:
  vars:
    cartridge_app_name: myapp
    cartridge_cluster_cookie: secret-cookie
    cartridge_package_path: ./myapp-1.0.0-0.rpm

  hosts:
    storage-1-leader:
      config:
        advertise_uri: '172.19.0.2:3301'

    storage-1-replica:
      config:
        advertise_uri: '172.19.0.2:3302'

  children:
    machine_1:
      vars:
        ansible_host: 172.19.0.2
        ansible_user: vagrant

      hosts:
        storage-1-leader:
        storage-1-replica:
```

Теперь объединим инстансы в репликасет.
Снова используем механизм групп, укажем общий для группы инстансов `replicaset_alias` и остальные параметры репликасета.

```yaml
---
all:
  vars:
    cartridge_app_name: myapp
    cartridge_cluster_cookie: secret-cookie
    cartridge_package_path: ./myapp-1.0.0-0.rpm

  hosts:
    storage-1-leader:
      config:
        advertise_uri: '172.19.0.2:3301'

    storage-1-replica:
      config:
        advertise_uri: '172.19.0.2:3302'

  children:
    machine_1:
      vars:
        ansible_host: 172.19.0.2
        ansible_user: vagrant

      hosts:
        storage-1-leader:
        storage-1-replica:

    replicaset_storage_1:
      hosts:
        storage-1:
        storage-1-replica:
      vars:
        replicaset_alias: storage-1
        roles:
          - vshard-storage
        failover_priority:
          - storage-1
          - storage-1-replica
```

Установим роль из Galaxy:

```bash
$ ansible-galaxy install tarantool.cartridge
```

Напишем простой playbook:

```yaml
# playbook.yml
---
- name: Deploy my Tarantool Cartridge app
  hosts: all
  become: true
  become_user: root
  any_errors_fatal: true
  gather_facts: false
  roles:
    - tarantool.cartridge
```

И запустим его:

```bash
ansible-playbook -i hosts.yml playbook.yml
```

### Сценарии

Запуск роли проделывает полную конфигурацию кластера - от установки пакета до конфигурации failover.
Но часто нам нужно сделать что-то одно, например, изменить топологию.

У роли есть механизм [сценариев](https://github.com/tarantool/ansible-cartridge/blob/master/doc/scenario.md).
Он позволяет указать последовательность шагов (steps), которые должны быть выполнены при текущем запуске.
Передать список шагов можно при помощи переменной `cartridge_scenario`:

```yaml
# playbook.yml
---
- name: Deploy my Tarantool Cartridge app
  hosts: all
  become: true
  become_user: root
  any_errors_fatal: true
  gather_facts: false
  roles:
    - tarantool.cartridge
  vars:
    cartridge_scenario:
      - edit_topology
```

Также есть возможность сохранять часто используемые последовательности шагов и составлять свои собственные сценарии.
Можно писать свои шаги и интегрировать их в плейбуки.
Роль также предоставляет несколько common-used [сценариев](https://github.com/tarantool/ansible-cartridge/blob/master/doc/scenario.md#scenarios).
Например, сценарий настройки инстансов или сценарий управления топологией.
Имя сценария можно указать при помощи `cartridge_scenario_name`.

```yaml
# playbook.yml
---
- name: Deploy my Tarantool Cartridge app
  hosts: all
  become: true
  become_user: root
  any_errors_fatal: true
  gather_facts: false
  roles:
    - tarantool.cartridge
  vars:
    cartridge_scenario_name: configure_topology
```

# Домашнее задание

Написать следующие плейбуки (активно используйте [документацию](https://github.com/tarantool/ansible-cartridge#documentation)):

* старт приложения с нуля:
  * старт 6 инстансов (роутер, 2 стораджа, 2 и 3 инстанса в каждом) на двух виртуалках;
  * vshard забутстраплен;
  * включен eventual failover;
  * (*) включен stateful failover со stateboard.
* rolling update:
  * установка нового пакета;
  * последовательный рестарт инстансов (по 2 штуки за раз);
* настройка авторизации;
* (*) написать свой шаг, который выводит информацию о текущем инстансе - имя, путь к сокету и имя репликасета.

RPM пакеты можно закоммитить в репозиторий с домашкой.
Для запуска виртуалок используйте Vagrantfile из практики.
В `README.md` должна содержаться инструкция такого вида:

* запуск виртуалок:

```
$ vagrant up
```

* раскатка кластера с нуля:

```
$ ansible-playbook -i hosts.yml playbook.start.yml
```

* rolling update:

```
$ ansible-playbook -i hosts.yml playbook.rolling.yml
```

и т.д.
