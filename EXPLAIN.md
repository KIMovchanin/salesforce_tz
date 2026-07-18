# Как устроен Item Purchase Tool

Этот файл — маршрут по проекту, а не дубликат README. README отвечает на вопрос «как установить и запустить», здесь разбирается «почему проект устроен именно так» и как читать применённый стек.

## С чего начать

Если цель сейчас — просто увидеть и проверить результат, локальный запуск не нужен. Приложение уже работает в облачной Dev Org `item-purchase-dev`: [откройте Item Purchase Tool для Demo Customer](https://orgfarm-3f2fc6c37b-dev-ed.develop.lightning.force.com/lightning/n/Item_Purchase_Tool?c__accountId=001dL00002MFkXwQAL), при необходимости войдите в Salesforce и повторно откройте ссылку. Локальные Node.js, pnpm и Salesforce CLI нужны только для разработки, тестов и deployment.

Откройте файлы в таком порядке:

1. `force-app/main/default/objects` — данные и ограничения.
2. `force-app/main/default/lwc/itemPurchaseTool` — пользовательский сценарий.
3. `PurchaseToolController.cls` — публичный контракт UI с сервером.
4. `ItemCatalogService.cls`, `ItemCreationService.cls`, `PurchaseCheckoutService.cls` — бизнес-правила.
5. `force-app/main/default/flows` — автоматизация после DML.
6. `UnsplashClient.cls` и credential metadata — внешняя интеграция.
7. `*Test.cls` и `lwc/**/__tests__` — зафиксированное ожидаемое поведение.

Такой порядок идёт от устойчивой модели к деталям реализации. Если начать с отдельных обработчиков кнопок, границы системы будут казаться случайными.

## 1. Ментальная модель Salesforce-проекта

Salesforce-приложение состоит из двух частей:

- source в Git: Apex, LWC и XML metadata;
- org: скомпилированный код, реальные записи, пользователи, разрешения и секреты.

XML в `force-app/main/default` — не конфигурация локального сервера. При deployment Salesforce превращает эти файлы в объекты, поля, layouts, Flows, permission sets и страницы внутри org.

Поэтому репозиторий намеренно не содержит:

- Unsplash Access Key;
- получателей из Hierarchy Custom Setting;
- реальных пользователей;
- записей Account, Item и Purchase.

Эти данные принадлежат конкретной org. Код описывает их форму и правила, а post-install настройка заполняет окружение.

## 2. Почему сначала построена модель данных

Интерфейс можно переписать без миграции бизнес-данных. Ошибочная связь Master-Detail или неверная точность Number исправляется намного дороже. Поэтому модель задаёт архитектуру.

### Purchase и PurchaseLine

`Purchase__c` — заголовок операции, `PurchaseLine__c` — снимок позиции на момент оформления.

В строке хранится `UnitCost__c`, хотя актуальная цена уже есть в Item. Это не повторение данных, а исторический снимок. Если менеджер изменит цену Item завтра, вчерашний Purchase не должен пересчитаться.

`Amount__c` означает количество, а не деньги. Название сохранено из технического задания.

### Два Master-Detail

PurchaseLine зависит и от Purchase, и от Item. Master-Detail даёт строгую ссылочную целостность и controlled-by-parent sharing.

У этого решения есть цена: удаление master может каскадно удалить строки. Поэтому пользовательские permission sets не дают delete на Item. В прикладной системе для долговременной истории чаще использовали бы Lookup к Item или отдельный snapshot object, но здесь сохранена требуемая модель.

### Почему Description — Text(255)

Техническое задание требует String и поиск по Description. Long Text Area нельзя использовать в обычном SOQL `LIKE`-условии. Text(255) сохраняет поиск на стороне базы и не вынуждает загружать весь каталог в браузер.

### Почему Recipient User — Text(18)

Hierarchy Custom Settings не поддерживают relationship fields. Создать настоящий Lookup(User) в этом типе metadata невозможно.

Поэтому `Recipient_User__c` хранит Salesforce Id:

- API name совпадает с заданием;
- длина ограничена 18 символами;
- Flow делает Get Records по User;
- Bell отправляется только активному найденному User;
- fault при некорректном Id обработан и переводит выполнение на email-ветку, не блокируя изменение Item.

Это осознанная адаптация несовместимого требования к возможностям платформы.

## 3. Как разделён Apex

### PurchaseToolController

Controller — фасад для LWC. Он не содержит запросы, DML и большие правила. Его задачи:

- объявить пять понятных UI-операций;
- вызвать нужный service;
- превратить ожидаемую доменную ошибку в `AuraHandledException`;
- не отдавать браузеру внутренний stack trace.

Тонкий controller проще тестировать и менять. Если позже появится второй интерфейс, services можно использовать повторно.

### PurchaseToolException

Это тип ожидаемой бизнес-ошибки: пустая корзина, недостаточный остаток, слишком длинный search, недопустимое значение при создании Item или отсутствие изображения.

Ожидаемая ошибка сообщает пользователю причину. Неожиданная ошибка получает стабильное безопасное сообщение и не раскрывает внутреннее устройство org.

### ItemCatalogService

Service нормализует фильтры, ограничивает длину поиска и строит SOQL из разрешённого набора условий.

Значения передаются через bind variables. Строка пользователя не вставляется в SOQL напрямую, поэтому символы поиска не превращаются в произвольный запрос.

`Database.queryWithBinds(..., AccessLevel.USER_MODE)` одновременно применяет sharing, CRUD и field-level security пользователя.

Лимит 500 защищает heap, время ответа и DOM от неограниченного каталога.

### PurchaseToolAuthorization

LWC скрывает Create Item для удобства, но это не защита. Пользователь может вручную вызвать Apex endpoint.

Поэтому `ItemCreationService` всегда заново проверяет `User.IsManager__c`. Затем user-mode insert проверяет, что у пользователя есть CRUD/FLS из manager permission set. Нужны оба условия:

- business flag отвечает «считает ли система этого пользователя менеджером»;
- permission set отвечает «какие технические операции ему разрешены».

### ItemCreationService и UnsplashClient

Последовательность намеренно такая:

1. авторизация;
2. валидация полей;
3. HTTP callout;
4. insert Item.

Salesforce запрещает обычный callout после незавершённого DML в той же транзакции. Вызов Unsplash до insert избегает ошибки `uncommitted work pending` и не оставляет Item без изображения.

`UnsplashClient` принимает только URL с ожидаемого `images.unsplash.com`. Даже корректный HTTP 200 не считается доверенным, пока структура JSON и host не проверены.

## 4. Главная транзакция: checkout

Checkout — наиболее критичная часть проекта, потому что два пользователя могут купить последний товар одновременно.

### Шаг 1. Нормализация корзины

Браузер отправляет только Item Id и quantity. Повторяющиеся строки одного Item складываются на сервере.

Проверяются:

- наличие хотя бы одной строки;
- максимум 100 входных строк;
- наличие Item Id;
- положительное целое quantity;
- допустимая числовая точность.

Клиентская валидация улучшает UX, серверная обеспечивает целостность.

### Шаг 2. Row locking

SOQL `FOR UPDATE` блокирует выбранные Item до конца транзакции.

Представьте остаток 1 и два одновременных checkout:

- первая транзакция блокирует Item и уменьшает остаток;
- вторая ждёт освобождения блокировки;
- после ожидания она обычно читает уже новый остаток и получает «not enough stock»;
- при превышении lock timeout она получает безопасное сообщение `Inventory is being updated`.

Без блокировки обе транзакции могли бы прочитать 1 и продать две единицы.

`ORDER BY` с locking query в Salesforce запрещён. Платформа использует подразумеваемый Id order, поэтому в запросе его нет.

### Шаг 3. Сервер — источник истины

LWC не передаёт цену. Service читает `Item.Price__c` после блокировки и записывает её в `PurchaseLine.UnitCost__c`.

Это закрывает простой сценарий подмены payload в DevTools. Аналогично остаток проверяется по базе, а не по устаревшей карточке на экране.

### Шаг 4. User mode и узкий system mode

Account и Item читаются в user mode, поэтому checkout учитывает sharing, CRUD и FLS вызывающего пользователя. Самому пользователю не выданы Create/Edit на Purchase и PurchaseLine: иначе он смог бы добавить строку через API или related list, подменить цену и не уменьшить остаток.

В API 67.0 особенно важно не оставлять режим выполнения подразумеваемым. Plain SOQL/DML в целевой версии следует новому user-mode поведению, поэтому код обозначает намерение явно: пользовательские чтения и создание Item выполняются через `USER_MODE`, а только доверенная внутренняя часть checkout, пересчёт итогов и изменение склада — через `SYSTEM_MODE`. Благодаря этому при чтении метода сразу видно, где применяются CRUD/FLS/sharing пользователя, а где платформа временно выполняет защищённое бизнес-действие от имени системы.

Важно проверить и профиль пользователя: permission set может добавить право, но не отозвать Create/Edit, уже выданные профилем. Полный доступ System Administrator допустим как доверенный административный контур, но не как профиль обычного покупателя.

После всех проверок service создаёт Purchase/Lines и уменьшает stock в контролируемом system mode. Это не общий обход безопасности: публичный entry point один, payload нормализован, цена прочитана с заблокированного Item, а Purchase получает текущего пользователя владельцем. Private OWD оставляет другим пользователям чужие покупки закрытыми.

### Шаг 5. Savepoint

Savepoint ставится до операций. Если строка, Flow, validation rule или stock update завершается ошибкой, rollback удаляет Purchase, PurchaseLines и возвращает остатки.

Пользователь не получает «половину покупки».

## 5. Как устроен LWC

### Композиция

`itemPurchaseTool` хранит состояние страницы и вызывает Apex. Остальные компоненты отвечают за один визуальный фрагмент:

- `itemTile` — карточка;
- `itemDetailsModal` — детали;
- `itemCartModal` — редактирование корзины;
- `itemCreateModal` — форма менеджера;
- `modalShell` — единая SLDS modal-разметка и Escape/focus behaviour.

Общая modal shell убирает копирование backdrop, header, footer и accessibility attributes.

### Однонаправленный поток данных

Родитель передаёт child-компонентам данные через `@api`. Child не изменяет родительскую корзину напрямую, а отправляет `CustomEvent`.

Например:

1. Item Tile отправляет `additem`;
2. parent проверяет stock;
3. parent создаёт новый массив cart;
4. LWC повторно отображает изменённое состояние.

Так легче понять, кто владеет данными, и избежать скрытых мутаций.

### Account context

Кнопка Account добавляет `c__accountId` в URL App Page. `CurrentPageReference` читает параметр, а `getRecord` получает Account.

Name объявлен обязательным field. AccountNumber и Industry — optional fields: если профиль не видит одно из них, вся страница не падает.

Компонент также поддерживает `recordId`, поэтому его можно разместить на Account Record Page.

### Поиск и гонки ответов

Search запускается на событие `change`; отдельного debounce сейчас нет. Старый запрос иногда отвечает после нового, поэтому `requestSequence` помечает каждый вызов, и компонент принимает только последний ответ. Иначе быстрый ввод мог бы вернуть каталог к устаревшему поиску.

### Корзина и фильтры

Корзина хранится отдельно от текущего списка результатов. Если пользователь добавил товар, а затем применил другой фильтр, строка не исчезает.

При повторной загрузке каталога совпавшие Item обновляются свежим остатком, а скрытые фильтром позиции сохраняются. Финальную проверку всё равно делает checkout service.

### Навигация

После успешного checkout используется `NavigationMixin` с `standard__recordPage`. Это открывает стандартную Purchase page, где layout показывает заголовок и related Purchase Lines.

## 6. Почему расчёты сделаны Flow + Apex action

Требование явно просит Record-Triggered Flow. Поэтому триггером изменений являются Flows, а не Apex Trigger.

Сам aggregate вынесен в `PurchaseTotalsFlowAction`, потому что он:

- принимает сразу набор Purchase Id;
- выполняет один aggregate SOQL для строк;
- считает несколько родителей без запросов внутри цикла;
- делает один bulk update Purchase;
- одинаково работает для create, update и delete;
- суммирует formula field `LineTotal__c`, поэтому число исходных строк не расходует лимит 50 000 query rows.

### After-save Flow

После create/update PurchaseLine запись уже существует в базе, поэтому action просто суммирует все строки текущего Purchase.

### Before-delete Flow

В before-delete момент удаляемая строка ещё видна SOQL. Flow передаёт её Id как `excludedLineId`, и action пропускает её при суммировании.

Так итог становится правильным внутри той же delete-транзакции.

## 7. Out-of-stock automation

Flow запускается только на update Item и только когда запись изменилась так, что `AvailableQuantity__c = 0`.

Это важнее простой проверки «сейчас ноль»: повторное изменение другого поля у уже пустого Item не создаёт повторный alert.

Дальше Flow:

1. читает `$Setup.Inventory_Notification_Settings__c`;
2. ищет активного User по сохранённому Id;
3. находит Custom Notification Type;
4. собирает collection получателей;
5. отправляет Bell;
6. независимо вызывает email action.

Fault path поиска User и Bell ведёт к email. Ошибка Bell или некорректный Recipient User ID не должны лишать менеджера второго канала и не должны откатывать stock update.

Email action рендерит требуемый template для каждого Item, но вызывает `Messaging.sendEmail` один раз для всей коллекции. Это bulkification: governor limit расходуется на один invocation, а результаты сопоставляются с исходными запросами.

## 8. Как защищён Unsplash Access Key

В Apex указан только логический endpoint:

`callout:Unsplash_API/search/photos`

Физический URL хранит Named Credential. External Credential формирует header:

`Authorization: Client-ID <AccessKey>`

Metadata содержит формулу и имя параметра, но не значение AccessKey. После deployment администратор создаёт encrypted authentication parameter через Setup или `scripts/configure-unsplash.ps1`.

Manager permission set содержит:

- доступ к principal External Credential;
- `Read + View All` для UserExternalCredential.

Обычному пользователю эти права не нужны, потому что Unsplash вызывается только при manager-only создании Item.

## 9. Permission sets

### Item Purchase User

Базовый permission set даёт:

- доступ к app и tab;
- Apex controller и Flow actions;
- чтение Account и Item;
- чтение собственных Purchase и PurchaseLine;
- чтение итогов без права их редактировать;
- вызов checkout, который один имеет право системно создать согласованную покупку.

### Item Purchase Manager

Это дополнение, а не замена базового permission set. Оно даёт:

- create/edit Item;
- External Credential principal access;
- минимальный доступ к зашифрованному UserExternalCredential.

Поэтому менеджеру всегда назначаются `Item_Purchase_User` и `Item_Purchase_Manager`.

## 10. Как читать тесты

### PurchaseTestFactory

Factory создаёт общие Account, Item, Purchase, lines, users и cart DTO. Он убирает копирование setup-кода и оставляет тестам только важное различие сценариев.

Test setup и технические assertion-запросы используют явный `SYSTEM_MODE`. Это нужно из-за поведения API 67.0: тест должен гарантированно подготовить и затем увидеть служебные данные независимо от CRUD/FLS пользователя внутри `System.runAs`. Проверяемый production-вызов при этом не получает лишних прав — его `USER_MODE` и узкие `SYSTEM_MODE` участки остаются теми же, что в реальной работе.

### Checkout tests

Обратите внимание на четыре категории:

- happy path: duplicate Item объединяются, цена берётся с сервера, остаток уменьшается;
- input validation: null, zero, fraction, слишком большая корзина;
- domain validation: удалённые records и недостаточный stock;
- transaction safety: overflow в downstream totals вызывает полный rollback.

Проверка `TotalItems = 6` и `GrandTotal = 375.25` подтверждает не только Apex service, но и after-save Flow.

Отдельный delete-тест подтверждает before-delete Flow.

### Unsplash tests

`HttpCalloutMock` заменяет сеть. Тесты проверяют success, 429, 5xx, invalid JSON, пустой result и неподдерживаемый image host.

Unit test не должен зависеть от доступности Unsplash или реального Access Key.

### Email и inventory Flow

Тест использует развёрнутый template, создаёт изолированный Hierarchy Setting, переводит Item из 5 в 0 и проверяет ровно один email invocation. Отдельная управляемая подмена developer name проверяет ветку отсутствующего template без mixed-DML setup.

Bell ветка в этом сценарии пропускается пустым Recipient User, поэтому тест остаётся детерминированным.

### LWC Jest

Jest работает в jsdom и подменяет Apex imports. Тестируется видимая разметка, события, manager state, stock guard, cart payload и navigation.

Jest не запускает реальный Apex. Apex tests не запускают настоящий браузер. Оба слоя нужны, потому что проверяют разные границы.

## 11. Как проходит deployment

`manifest/package.xml` перечисляет deployable metadata. Email folder и template указаны явно: folder-based metadata не следует оставлять на wildcard, иначе template может не войти в manifest conversion.

В текущей Dev Org `item-purchase-dev` этот путь уже пройден:

1. full deployment завершён успешно, Id `0AfdL00000dqf8gSAA`;
2. текущему пользователю назначены `Item_Purchase_User` и `Item_Purchase_Manager`, `IsManager__c = true`;
3. Inventory Notification Settings заполнен;
4. создан System Administrator с email `dev@truesolv.com`;
5. созданы Account `Demo Customer` (`001dL00002MFkXwQAL`) и четыре demo Item;
6. Apex run `707dL00001FHl8Z` завершён: 28/28 tests passed, org-wide coverage 92%;
7. загружен unmanaged package `033dL000000fPdZ`, версия 1.0 `04tdL000000kB25QAE`, 74 components.

Installation URL: [Item Purchase Tool 1.0](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tdL000000kB25QAE).

Из org-specific настроек пока не добавлен только Unsplash Access Key. Поэтому существующие demo images работают, а создание нового Item через Unsplash начнёт работать после отдельной настройки encrypted credential. Исходники опубликованы в приватном репозитории `https://github.com/KIMovchanin/salesforce_tz`, а URL отправлен на `dev@truesolv.com`. Для просмотра репозитория получателю всё равно нужно выдать GitHub-доступ.

## 12. Как самостоятельно проверить сценарий

### Быстрая проверка готовой Dev Org

1. Откройте [готовую страницу Demo Customer](https://orgfarm-3f2fc6c37b-dev-ed.develop.lightning.force.com/lightning/n/Item_Purchase_Tool?c__accountId=001dL00002MFkXwQAL).
2. Если появилась форма входа, войдите в Salesforce и откройте ссылку ещё раз.
3. Найдите `chair`, затем очистите поиск и проверьте Type/Family filters.
4. Добавьте Item с положительным остатком в Cart, измените quantity и выполните Checkout.
5. Проверьте созданный Purchase, Purchase Lines, `TotalItems` и `GrandTotal`.
6. Убедитесь, что `Desk Lamp` с нулевым остатком нельзя добавить в Cart.

Для этих действий ничего локально запускать не нужно. Кнопку создания нового Item проверяйте после настройки Unsplash Access Key; четыре уже загруженных товара и их изображения доступны сейчас.

### Каталог

1. Используйте четыре подготовленных Item разных Type и Family.
2. Проверьте отдельные и совместные фильтры.
3. Найдите Item по слову только из Description.
4. Быстро изменяйте search и убедитесь, что остаётся последний результат.

### Склад

1. Создайте Item с quantity 1.
2. Откройте Tool в двух вкладках.
3. Добавьте Item в обе корзины.
4. Выполните checkout почти одновременно.
5. Одна покупка должна пройти, другая получить stock error или безопасный lock-timeout ответ.

### Manager security

1. У обычного User измените DOM или вызовите Apex вручную.
2. Сервер всё равно должен отклонить создание Item.
3. Установите только `IsManager__c`, но не manager permission set: user-mode DML должен отказать.
4. Назначьте оба permission sets: создание должно пройти.

### Notification transition

1. Установите quantity 2 → 1: уведомления нет.
2. Установите 1 → 0: приходят Bell и email.
3. Измените Description при quantity 0: повторного уведомления нет.
4. Пополните 0 → 1, затем снова 1 → 0: приходит новый alert.

## 13. Где искать проблемы

### LWC показывает generic error

Сначала откройте browser console и Network, затем Salesforce Debug Logs. Controller намеренно скрывает необработанные детали от пользователя, но server log сохраняет исходное исключение.

### Checkout не создаёт Purchase

Проверьте по порядку:

1. Account Id в URL;
2. базовый permission set;
3. CRUD/FLS Purchase и PurchaseLine;
4. validation rules;
5. fault email от Flow;
6. `UNABLE_TO_LOCK_ROW` при параллельной операции.

### Unsplash возвращает ошибку

Проверьте principal status, manager permission set, UserExternalCredential access, Allow Formulas in HTTP Header и лимит Unsplash.

### Итоги не обновляются

Убедитесь, что оба Purchase Line Flow имеют status Active, action class доступен и Purchase layout показывает read-only fields.

### Нет уведомлений

Проверьте именно переход в ноль, а не создание Item с нулём. Затем проверьте Custom Setting, активность User, Deliverability и Custom Notification Type.

## 14. Что можно развить дальше

Эти улучшения не входят в задание, но показывают естественное направление продукта:

- pagination вместо лимита 500;
- idempotency key для безопасного повторного checkout после network timeout;
- configurable currency и locale-aware price model;
- отдельная Inventory Transaction ledger вместо изменения одного числа;
- Platform Events или async email для очень больших bulk-операций;
- custom metadata для управляемых Type/Family наборов;
- Account Lightning Record Action вместо layout button для организаций с разными layouts;
- observability object или event для ошибок внешней интеграции.

Важно не добавлять эти механизмы заранее без требования: каждый создаёт новые metadata, права, тесты и operational cost.

## Краткий словарь

| Термин                   | Значение в проекте                                                   |
| ------------------------ | -------------------------------------------------------------------- |
| LWC                      | Клиентские компоненты Lightning на JavaScript/HTML/CSS               |
| Apex                     | Серверный язык Salesforce с транзакциями и governor limits           |
| SLDS                     | Стандартная дизайн-система Lightning                                 |
| Flow                     | Декларативная автоматизация, запускаемая изменением records          |
| CRUD/FLS                 | Права на object и отдельные fields                                   |
| Sharing                  | Видимость конкретных records                                         |
| User mode                | Выполнение с CRUD/FLS/sharing вызывающего User                       |
| System mode              | Выполнение без части пользовательских ограничений; используется узко |
| Named Credential         | Логический endpoint внешнего сервиса                                 |
| External Credential      | Authentication protocol, principal и зашифрованные параметры         |
| Hierarchy Custom Setting | Org/Profile/User-конфигурация, доступная через `$Setup`              |
| Savepoint                | Точка полного отката текущей Apex-транзакции                         |
| Row lock                 | Блокировка records от конкурентного изменения                        |
| Invocable Apex           | Apex method, который Flow может вызвать как action                   |

Если после чтения вы можете объяснить, почему цена не приходит из LWC, зачем одновременно нужны `FOR UPDATE` и savepoint, и почему manager получает два permission sets, значит ключевая архитектура проекта уже понятна.
