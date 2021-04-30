## Тестирование

На предыдущем занятии мы рассмотрели деплой.
Мы поняли, что делать с приложением после написания,
как доставлять его до серверов, запускать, эксплуатировать.

В этот раз будет нечто среднее. С одной стороны, мы отойдем на
шаг назад, с другой стороны посмотрим, что происходит с системой
уже после деплоя.

Итак, у нас есть большое-большое приложение. Мы делаем в нем очередное изменение
и... какая-то часть функционала перестает работать.
Если ошибка появляется уже во время промышленной эксплуатации - страдают
пользователи, уходят от нас, что приводит к финансовым и репутационным потерям.

И данную проблему помогает решить тестирование.
По сути, после каждого изменения нам нужно проверять, а
не сломали ли мы что-то. И это можно делать руками - но это долго.
Особенно если в нашем приложении сотни тысяч - миллионы строк кода.
Так мы приходим к необходимости автоматического тестирования.
Оно возможно не всегда - например, проверять интерфейсы лучше руками.
Но при работе с серверными приложениями автоматизированное тестирование
чаще всего возможно.

Итак, пока мы можем классифицировать тестирование по двум направлениям -
ручное и автоматическое. Но, на самом деле, всё куда обширнее и тестирование
может производится с разным знанием о системе (методом черного/серого/белого
ящика) или тестироваться могут разные компоненты системы (отдельно/в связке
друг с другом...).

Было сказано много слов, но в общем данное занятие не ставит целью
рассказать максимально подробно про тестирование. Мы будем разбирать
инструменты, с помощью которых можно писать свои тесты.

### Тестирование на примере Python

Каким бы языком вы не начали пользоваться,
обычно существуют уже готовые фреймворки для тестирования.
Так в языке Python есть встроенный модуль unittest.

Попробуем написать какой-нибудь простой тест.
Будем тестировать некоторый абстрактный стек.
Даже без запуска можно пройтись по примитивам, которые
используются в тестах:

* test fixture - подготовка, необходимая для выполнения тестов и все необходимые действия для очистки после выполнения тестов.
Это может включать, например, создание временных баз данных или запуск серверного процесса.
* test case - минимальный блок тестирования. Он проверяет ответы для разных наборов данных.
* test suite - несколько тестовых случаев, наборов тестов или и того и другого.
Используется для объединения тестов, которые должны быть выполнены вместе.
* test runner - компонент, который управляет выполнением тестов и предоставляет пользователю результат.
Исполнитель может использовать графический или текстовый интерфейс или возвращать специальное значение, которое сообщает о результатах выполнения тестов.

```py
import unittest
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(__file__)))
from stack import Stack


class TestStack(unittest.TestCase):
    def setUp(cls):
        print('Test started')

    def test_empty(self):
        stack = Stack()
        self.assertIsNone(stack.pop())
        self.assertIsNone(stack.top())

    def test_push_pop(self):
        stack = Stack()
        input_values = [1, 'abc', 'test', {}]
        output_values = input_values.copy()
        output_values.reverse()

        for value in input_values:
            stack.push(value)
            self.assertEqual(value, stack.top())

        for expected in output_values:
            value = stack.pop()
            self.assertEqual(expected, value)

        self.assertIsNone(stack.pop())
        self.assertIsNone(stack.top())

    def test_clear(self):
        stack = Stack()
        stack.push('value')
        self.assertIsNotNone(stack.top())
        stack.clear()
        self.assertIsNone(stack.top())
```

Запуск выглядит примерно так:
```bash
python3 -m unittest discover -v test
test_clear (test_stack.TestStack) ... ok
test_empty (test_stack.TestStack) ... ok
test_push_pop (test_stack.TestStack) ... ok

----------------------------------------------------------------------
Ran 3 tests in 0.000s

OK
```

Как следует из названия unittest в первую очередь предназначен для тестирования
изолированных модулей. Для интеграционного тестирования обычно используются
другие фреймворки, например [Pytest](https://docs.pytest.org/).

### Тестирование в Tarantool

#### TAP

Для написания простых тестов Tarantool имеет встроенный модуль `tap` - [Test Anything Protocol](https://testanything.org/).

```lua
#!/usr/bin/env tarantool
local semver = require('common.semver')

local tap = require('tap')

local test = tap.test('semver tests')

test:plan(1)

test:test('validate_operator', function(t)
    local subject = semver.validate_operator
    t:plan(8)
    t:is(subject('=='), true)
    t:is(subject('<='), true)
    t:is(subject('>='), true)
    t:is(subject('<'), true)
    t:is(subject('>'), true)
    t:is(subject('='), false)
    t:is(subject('<>'), false)
    t:is(subject('~'), false)
end)

os.exit(test:check() and 0 or 1)
```

Результат:
```log
TAP version 13
1..1
    # validate_operator
    1..8
    ok - nil
    ok - nil
    ok - nil
    ok - nil
    ok - nil
    ok - nil
    ok - nil
    ok - nil
    # validate_operator: end
ok - validate_operator
```

#### Test-run

Написанный на Python, фреймворк для тестирования самого Tarantool - https://github.com/tarantool/test-run.

#### Luatest

Фреймворк для тестирования, написанный на Lua.

```lua
local server = luatest.Server:new({
    command = '/path/to/executable.lua',
    -- arguments for process
    args = {'--no-bugs', '--fast'},
    -- additional envars to pass to process
    env = {SOME_FIELD = 'value'},
    -- passed as TARANTOOL_WORKDIR
    workdir = '/path/to/test/workdir',
    -- passed as TARANTOOL_HTTP_PORT, used in http_request
    http_port = 8080,
    -- passed as TARANTOOL_LISTEN, used in connect_net_box
    net_box_port = 3030,
    -- passed to net_box.connect in connect_net_box
    net_box_credentials = {user = 'username', password = 'secret'},
})
server:start()
-- Wait until server is ready to accept connections.
-- This may vary from app to app: for one server:connect_net_box() is enough,
-- for another more complex checks are required.
luatest.helpers.retrying({}, function() server:http_request('get', '/ping') end)

-- http requests
server:http_request('get', '/path')
server:http_request('post', '/path', {body = 'text'})
server:http_request('post', '/path', {json = {field = value}, http = {
    -- http client options
    headers = {Authorization = 'Basic ' .. credentials},
    timeout = 1,
}})

-- This method throws error when response status is outside of then range 200..299.
-- To change this behaviour, path `raise = false`:
t.assert_equals(server:http_request('get', '/not_found', {raise = false}).status, 404)
t.assert_error(function() server:http_request('get', '/not_found') end)

-- using net_box
server:connect_net_box()
server.net_box:eval('return do_something(...)', {arg1, arg2})

server:stop()
```

Основные возможности:
  * Набор функций для управления инстансами Tarantool;
  * Подходит не только для юнит, но и для интеграционнных тестов;
  * Можно запускать с помощью Tarantool - не требуется дополнительных зависимостей.

#### Упражнение

Написать простое CRUD-приложение (1 инстанс) и протестировать его.

### Нефункциональное тестирование

Обычно, кроме работающей логики, нас ещё и интересует, насколько
быстро она выполняется.
В частности, мы хотим оценивать сколько запросов за единицу времени
способен обработать наш сервис.
Для таких тестов используются другие фреймворки - их существует
достаточно большое количество и с достаточно большим разбросом функциональности.
В курсе мы будем рассматривать [wrk](https://github.com/wg/wrk).
С помощью небольших луа-скриптов мы сможем формировать запросы,
которые затем будут посылаться на сервер.
В конце мы получаем небольшой отчет следующего формата:
```
# wrk -s script.lua -c 1000 -t 20 -d 1m http://localhost:8081
Running 1m test @ http://localhost:8081
  20 threads and 1000 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   153.47ms   61.78ms   1.99s    72.15%
    Req/Sec   102.51     81.21   594.00     75.83%
  114860 requests in 1.00m, 14.67MB read
  Socket errors: connect 0, read 8157, write 31, timeout 352
  Non-2xx or 3xx responses: 12188
Requests/sec:   1911.07
Transfer/sec:    250.00KB
```

У самого скрипта есть специальный формат:
```lua
local function read_file(path)
    local file = io.open(path, 'r')
    if file == nil then
        error(('Failed to open file %s'):format(path))
    end
    local buf = file:read('*a')
    file:close()
    return buf
end

id = 1
function setup(thread)
    thread:set('ctn', id)
    thread:set('id', id)
    id = id + 1
    thread:set('body', read_file('test_data.json'))
end

function request()
    ctn = ctn + id
    local req = wrk.format('POST', '/http', { ['Content-Type'] = 'application/json' }, body)
    return req
end

function done(summary, latency, requests)
   print(summary, latency, requests)
end
```

Более подробно и с примерами можно посмотреть [тут](https://github.com/wg/wrk/tree/master/scripts).

Выбор инструментов для нагрузочного тестирования довольно широк.
Из довольно известных стоит отметить [Yandex.Tank](https://github.com/yandex/yandex-tank) и [JMeter](https://jmeter.apache.org/).

## Мониторинг

Работающее приложение - не является чем-то статическим.
Более того, его нельзя просто запустить и забыть о нем.
Необходимо отслеживать состояние приложения, чтобы своевременно
реагировать на различного рода ситуации (в том числе аварийные).

Это решается с помощью мониторинга.
Ваше приложение должно предоставлять некоторый набор метрик
(например, количество удачно обработанных запросов, количество неудачно обработанных
запросов, количество запросов, обрабатываемых за единицу времени),
также бывают интересны метрики платформы, на которой работает приложение, например,
количество свободной памяти.

Давайте рассмотрим мониторинг с двух позиций - хранения и визуализация.

### Prometheus

[Prometheus](https://prometheus.io/) - это time-series database - база данных
для хранения временных рядов. Т.е. данная база предназначена для
хранения некоторых показаний, изменяющихся во времени.
Кроме этого, предполагается, наличие специальных запросов к таким данным.

![image](https://user-images.githubusercontent.com/8830475/111695099-c2f5b100-8843-11eb-8759-1902d6e207ee.png)

![image](https://user-images.githubusercontent.com/8830475/111695146-d30d9080-8843-11eb-92dd-890bf1d9c259.png)

Откуда беруться данные? Есть две стратегии - Push и Pull - т.е. само приложение может присылать
метрики или наоборот Prometheus может периодически опрашивать приложение.
Поведением по умолчанию является именно второй вариант.
Обычно приложение выставляет некоторый HTTP-эндпоинт, куда в специальном
формате выгружаются метрики.
```
# HELP tnt_info_memory_data Memorydata
# TYPE tnt_info_memory_data gauge
tnt_info_memory_data 1025016
# HELP tnt_info_memory_index Memoryindex
# TYPE tnt_info_memory_index gauge
tnt_info_memory_index 3162112
# HELP tnt_info_memory_lua Memorylua
# TYPE tnt_info_memory_lua gauge
tnt_info_memory_lua 51735433
# HELP tnt_info_memory_net Memorynet
# TYPE tnt_info_memory_net gauge
tnt_info_memory_net 63799584
```

В Prometheus используются следующие типы метрик:

* Счётчик (counter) — хранит значения, которые увеличиваются с течением времени
(например, количество запросов к серверу);
* Шкала (gauge) — хранит значения, которые с течением времени могут как увеличиваться,
так и уменьшаться (например, объём используемой оперативной памяти или количество операций ввода-вывода);
* Гистограмма (histogram) — хранит информацию об изменении некоторого параметра в течение определённого промежутка 
(например, общее количество запросов к серверу в период с 11 до 12 часов и количество запросов к этому же серверов в период с 11.30 до 11.40);
* Cводка результатов (summary) — как и гистограмма, хранит информацию об изменении значения некоторого параметра за временной интервал,
но также позволяет рассчитывать квантили для скользящих временных интервалов.

В Tarantool для работы с метриками есть специальный модуль - [metrics](https://github.com/tarantool/metrics).
Модуль позволяет экспортировать практически все метрики Tarantool (box.info(), box.stat(), box.slab(), ...) в
различных форматах (в том числе и Prometheus).
Также пользователю доступен инструментарий для создания своих метрик.

Попробуем запустить Prometheus.
Для этого нам понадобиться конфигурационный файл:
```yaml
global:
  scrape_interval: 1m # Set the scrape interval to every 15 seconds. Default is every 1 minute.
  evaluation_interval: 1m # Evaluate rules every 15 seconds. The default is every 1 minute.
  # scrape_timeout is set to the global default (10s).

# Alert manager configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets:
          # - alertmanager:9093

# Load rules once and periodically evaluate them according to the global 'evaluation_interval'.
rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:
  # The job name is added as a label `job=<job_name>` to any timeseries scraped from this config.
  - job_name: "prometheus"

    # metrics_path defaults to '/metrics'
    # scheme defaults to 'http'.

    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "example_project"
    static_configs:
      - targets: 
        - "localhost:8081"
        - "localhost:8082"
        - "localhost:8083"
        - "localhost:8084"
        - "localhost:8085"
    metrics_path: "/metrics/prometheus"
```

Здесь мы задаем то, где будет работать Prometheus (`localhost:9090`),
какие приложения будет опрашивать (`localhost:8081-8085`),
с какой периодичностью и по какому адресу.

Запуск - `prometheus --config.file="prometheus.yml"`.

После этого мы получаем доступ к UI на `localhost:9090`.

Можем посмотреть за тем, каково состояние инстансов, которые мы мониторим:
![image](https://user-images.githubusercontent.com/8830475/111697012-0d782d00-8846-11eb-9ce1-a7158a648c2a.png)

Можем делать запросы с помощью специального языка [PromQL](https://prometheus.io/docs/prometheus/latest/querying/basics/):

![image](https://user-images.githubusercontent.com/8830475/111697403-93947380-8846-11eb-8568-548465586faf.png)

Понятно, что воспринимать цифры достаточно сложно, поэтому требуется
некоторый UI, который бы мог использовать Prometheus в качестве источника данных.

### Grafana

<img src="https://user-images.githubusercontent.com/8830475/112750203-e9e47d80-8fcf-11eb-9fb7-890326155df9.png" height="100">

[Grafana](https://grafana.com/) — это платформа с открытым исходным кодом для визуализации,
мониторинга и анализа данных.
Grafana позволяет пользователям создавать дашборды с панелями,
каждая из которых отображает определенные показатели в течение установленного периода времени.
Каждый дашборд универсален,
поэтому его можно настроить для конкретного проекта или с учетом любых потребностей разработки и/или бизнеса.

![image](https://user-images.githubusercontent.com/8830475/111698158-8b890380-8847-11eb-99bc-aac9c47c7277.png)

![image](https://user-images.githubusercontent.com/8830475/111698911-73fe4a80-8848-11eb-9e32-ae35f025701d.png)

В качестве демонстрации рассмотрим [tarantool/grafana-dashboard](https://github.com/tarantool/grafana-dashboard).

Рекомендация: посмотреть на дашборд какого-либо приложения под нагрузкой.

### Tracing

Ещё один подход к интроспекции запросов - трассировка запросов.
В систему поступает запрос, он делится на некоторые стадии (парсинг запроса, вычисления, сохранение в БД и т.д),
мы хотим узнать, какая из стадий сколько выполняется.
Особенно интересно видеть поведение системы под нагрузкой - оно может отличаться от поведения
без нагрузки.

#### OpenTracing

<img src="https://user-images.githubusercontent.com/8830475/112750719-e69ec100-8fd2-11eb-8c38-3c7c0d3fa94f.png" height="100">

[OpenTracing](https://opentracing.io/) - спецификация, цель которой - унификация инструментов и методов
для трассировки запросов вне зависимости от платформы и языка программирования.

![image](https://user-images.githubusercontent.com/8830475/112750541-da663400-8fd1-11eb-8d15-13350f7ab348.png)

Рассмотрим примитивы, с которыми имеет дело OpenTracing.

* Trace - путь нашего запроса
* Span - блок кода, который трассируется
* SpanContext - контекст, который хранит в себе информацию о том, как Span'ы должны быть связаны между собой:
trace_id, span_id, parent_id...

После сбора информация отправляется в специальную систему, которая занимается
хранением, сборов и визуализацией трейсов. Примерами таких систем являются [Zipkin](https://zipkin.io/) и [Jaeger](https://www.jaegertracing.io/).

![image](https://user-images.githubusercontent.com/8830475/112750971-13070d00-8fd4-11eb-9a59-d5bf5a1dd74c.png)

В Tarantool работа с трейсингом возможна с помощью модуля [tracing](https://github.com/tarantool/tracing).

#### Домашнее задание

Для домашнего задания "CRUD" настроить экспорт метрик в формате Prometheus и Grafana Dashbord.
Самостоятельно выбрать список метрик и их типы
(написать в README.md краткий отчет по ним + скриншоты).
Провести нагрузочное тестирование каждой из операций (insert/get/...) -
предоставить отчет и скрипты для тестирования.
