# Item Purchase Tool

Одностраничное Salesforce-приложение для формирования покупки из карточки Account. Пользователь ищет и фильтрует товары, собирает корзину и оформляет Purchase; менеджер дополнительно создаёт товары с изображением из Unsplash. Остатки, итоги покупки и уведомления об исчерпании запаса обрабатываются на платформе Salesforce.

Проект реализован на Salesforce API 67.0 без Aura и без клиентского доступа к секретам.

## Возможности

- запуск Item Purchase Tool кнопкой с Account layout в отдельной вкладке;
- отображение Account Name, Account Number и Industry;
- поиск по Item Name и Description, фильтрация по Type и Family;
- карточки товаров, изображения, детали в модальном окне и счётчик результатов;
- корзина с количеством, построчными суммами, общей суммой и проверкой остатков;
- атомарный checkout с серверной ценой, блокировкой Item и откатом всей транзакции при ошибке;
- создание Purchase и PurchaseLine, уменьшение Available Quantity и переход на стандартную страницу Purchase;
- создание Item только для пользователя с `User.IsManager__c = true` и manager permission set;
- получение изображения через Unsplash API с защищённым Access Key;
- автоматический расчёт `TotalItems__c` и `GrandTotal__c` Record-Triggered Flow;
- Bell и email-уведомления при переходе остатка товара в ноль;
- permission sets для обычного пользователя и менеджера;
- Apex unit tests, LWC Jest tests, ESLint, Prettier и GitHub Actions.

## Архитектура

```mermaid
flowchart LR
    Account["Account layout button"] --> Page["Item Purchase Tool App Page"]
    Page --> LWC["itemPurchaseTool LWC"]
    LWC --> Controller["PurchaseToolController"]
    Controller --> Catalog["ItemCatalogService"]
    Controller --> Creation["ItemCreationService"]
    Creation --> Auth["Manager authorization"]
    Creation --> Unsplash["UnsplashClient + Named Credential"]
    Controller --> Checkout["PurchaseCheckoutService"]
    Checkout --> Lock["Item rows: FOR UPDATE"]
    Lock --> Purchase["Purchase + Purchase Lines"]
    Purchase --> TotalsFlow["Purchase Line totals Flows"]
    Checkout --> Stock["System-mode stock decrement"]
    Stock --> InventoryFlow["Out-of-stock Flow"]
    InventoryFlow --> Bell["Custom Bell Notification"]
    InventoryFlow --> Email["Bulk-safe Apex email action"]
```

### Слои

| Слой            | Компоненты                                                             | Ответственность                                                   |
| --------------- | ---------------------------------------------------------------------- | ----------------------------------------------------------------- |
| UI              | `itemPurchaseTool`, `itemTile`, модальные LWC                          | Состояние каталога и корзины, события, валидация ввода, навигация |
| Application API | `PurchaseToolController`                                               | Узкий `@AuraEnabled`-контракт и стабильные сообщения об ошибках   |
| Domain services | `ItemCatalogService`, `ItemCreationService`, `PurchaseCheckoutService` | Поиск, создание товара, checkout и правила склада                 |
| Security        | `PurchaseToolAuthorization`, permission sets                           | Manager gate, CRUD/FLS, sharing и доступ к External Credential    |
| Integration     | `UnsplashClient`, Named/External Credential                            | Вызов Unsplash без секрета в Apex или Git                         |
| Automation      | 3 Record-Triggered Flows, 2 invocable Apex actions                     | Итоги Purchase, Bell и email-уведомления                          |
| Metadata        | Objects, fields, layouts, app, tab, button, template, settings         | Декларативная модель и пользовательский доступ                    |
| Tests           | 6 Apex test classes, 6 Jest suites                                     | Позитивные, негативные, rollback, Flow и UI-сценарии              |

### Checkout-транзакция

1. Сервер проверяет Account и нормализует корзину, объединяя повторяющиеся Item.
2. Item читаются в user mode и блокируются `FOR UPDATE`.
3. Сервер повторно проверяет цену, целое количество и доступный остаток.
4. Purchase и PurchaseLine создаются контролируемым system-mode участком; прямой Create на эти objects пользователю не выдан.
5. Record-Triggered Flow пересчитывает `TotalItems__c` и `GrandTotal__c`.
6. Остатки уменьшаются через узкий system-mode gateway.
7. При переходе количества в ноль второй Flow отправляет Bell и email.
8. Любая необработанная ошибка откатывает Purchase, строки и изменения остатков к savepoint.

## Модель данных

| Object                               | Field                  | Type                | Назначение                                     |
| ------------------------------------ | ---------------------- | ------------------- | ---------------------------------------------- |
| `Purchase__c`                        | `Name`                 | Text                | Человекочитаемое имя покупки                   |
| `Purchase__c`                        | `ClientId__c`          | Lookup(Account)     | Account, для которого создана покупка          |
| `Purchase__c`                        | `TotalItems__c`        | Number(18,0)        | Сумма количеств строк, обновляется Flow        |
| `Purchase__c`                        | `GrandTotal__c`        | Number(18,2)        | Сумма `Amount × UnitCost`, обновляется Flow    |
| `PurchaseLine__c`                    | `PurchaseId__c`        | Master-Detail       | Родительская покупка                           |
| `PurchaseLine__c`                    | `ItemId__c`            | Master-Detail       | Купленный товар                                |
| `PurchaseLine__c`                    | `Amount__c`            | Number(18,0)        | Количество                                     |
| `PurchaseLine__c`                    | `UnitCost__c`          | Number(18,2)        | Цена на момент checkout                        |
| `PurchaseLine__c`                    | `LineTotal__c`         | Formula Number      | `Amount × UnitCost`, используется bulk totals  |
| `Item__c`                            | `Name`                 | Text                | Название товара и запрос к Unsplash            |
| `Item__c`                            | `Description__c`       | Text(255)           | Описание, доступное для SOQL `LIKE`-поиска     |
| `Item__c`                            | `Type__c`              | Restricted Picklist | Product, Accessory, Supply, Equipment          |
| `Item__c`                            | `Family__c`            | Restricted Picklist | Electronics, Furniture, Office Supplies, Other |
| `Item__c`                            | `Image__c`             | URL                 | Изображение с `images.unsplash.com`            |
| `Item__c`                            | `Price__c`             | Number(18,2)        | Серверная цена                                 |
| `Item__c`                            | `AvailableQuantity__c` | Number(18,0)        | Текущий остаток                                |
| `User`                               | `IsManager__c`         | Checkbox            | Разрешение бизнес-уровня на создание Item      |
| `Inventory_Notification_Settings__c` | `Recipient_User__c`    | Text(18)            | Salesforce User Id для Bell                    |
| `Inventory_Notification_Settings__c` | `Recipient_Email__c`   | Email               | Адрес для email-уведомлений                    |

`Recipient_User__c` хранится как Text(18), поскольку Salesforce не поддерживает relationship fields в Hierarchy Custom Settings. API name сохранён по техническому заданию, а Flow дополнительно проверяет, что User существует и активен.

## Структура репозитория

```text
.
├── .github/workflows/quality.yml
├── config/project-scratch-def.json
├── force-app/main/default
│   ├── applications
│   ├── classes
│   ├── cspTrustedSites
│   ├── email
│   ├── externalCredentials
│   ├── flexipages
│   ├── flows
│   ├── layouts
│   ├── lwc
│   ├── namedCredentials
│   ├── notificationtypes
│   ├── objects
│   ├── permissionsets
│   └── tabs
├── manifest/package.xml
├── scripts/configure-unsplash.ps1
├── eslint.config.js
├── jest.config.js
├── package.json
├── pnpm-lock.yaml
├── prettier.config.js
└── sfdx-project.json
```

## Технологии и зависимости

### Runtime

- Salesforce Apex 67.0;
- Lightning Web Components;
- Salesforce Lightning Design System;
- Record-Triggered Flows;
- Salesforce Named Credentials и External Credentials;
- Hierarchy Custom Setting;
- Classic Text Email Template;
- Custom Notification Type.

### Инструменты разработки

| Инструмент                  | Проверенная версия |
| --------------------------- | ------------------ |
| Node.js                     | 22                 |
| pnpm                        | 11.9.0             |
| Salesforce CLI              | 2.143.6            |
| `@salesforce/sfdx-lwc-jest` | 7.9.0              |
| ESLint                      | 9.39.5             |
| Prettier                    | 3.9.5              |
| `prettier-plugin-apex`      | 2.3.0              |

Runtime npm-зависимостей нет. Node-пакеты нужны только для форматирования, lint и LWC unit tests.

## Предварительные требования

- Salesforce Developer Edition org или scratch org с Lightning Experience;
- включённый Dev Hub для scratch org сценария;
- Salesforce CLI `sf`;
- Node.js 22 и pnpm;
- Unsplash developer account, зарегистрированное приложение и Access Key;
- права администратора для deployment и post-install конфигурации.

## Локальная установка

```powershell
pnpm install --frozen-lockfile
sf org login web --instance-url https://login.salesforce.com --alias item-purchase-dev --set-default
```

## Deployment

Для Developer Edition org:

```powershell
sf project deploy validate --manifest manifest/package.xml --target-org item-purchase-dev --test-level RunLocalTests --wait 30
sf project deploy start --manifest manifest/package.xml --target-org item-purchase-dev --test-level RunLocalTests --wait 30
```

Manifest содержит явные entries для email folder и template; wildcard для folder-based metadata намеренно не используется.

После deployment выполните post-install настройку, а затем серверные тесты:

```powershell
sf apex run test --test-level RunLocalTests --target-org item-purchase-dev --wait 30 --code-coverage --result-format human
```

Для scratch org:

```powershell
sf org login web --instance-url https://login.salesforce.com --alias item-purchase-devhub --set-default-dev-hub
sf org create scratch --target-dev-hub item-purchase-devhub --definition-file config/project-scratch-def.json --alias item-purchase-scratch --set-default --duration-days 7
sf project deploy start --manifest manifest/package.xml --target-org item-purchase-scratch --wait 30
```

## Post-install конфигурация

### 1. Unsplash Access Key

Секрет не входит в metadata, package или Git. Это обязательное ограничение Salesforce External Credentials.

```powershell
$env:UNSPLASH_ACCESS_KEY = 'your-access-key'
pnpm configure:unsplash item-purchase-dev
Remove-Item Env:UNSPLASH_ACCESS_KEY
```

Скрипт передаёт ключ в Connect REST API через stdin. Ключ не записывается в файл и не попадает в командную строку дочернего процесса.

Эквивалентная ручная настройка:

1. Откройте Setup → Named Credentials → External Credentials.
2. Выберите `Unsplash API Key` (`Unsplash_API_Key`).
3. В principal `Unsplash_Principal` добавьте Authentication Parameter:
   - Name: `AccessKey`;
   - Value: Unsplash Access Key.
4. Убедитесь, что статус principal — Configured.

### 2. Permission sets и manager flag

Обычному пользователю назначается базовый permission set. Значение после `--on-behalf-of` — Salesforce Username, а не поле Email:

```powershell
sf org assign permset --name Item_Purchase_User --target-org item-purchase-dev --on-behalf-of user@example.com
```

Профиль прикладного пользователя не должен отдельно выдавать Create/Edit на `Purchase__c` и `PurchaseLine__c`: permission set умеет только добавлять права и не может отозвать уже выданные профилем. System Administrator остаётся доверенным исключением с полным доступом.

Менеджеру назначаются оба permission sets. Здесь также используются Salesforce Username:

```powershell
sf org assign permset --name Item_Purchase_User --target-org item-purchase-dev --on-behalf-of manager@example.com
sf org assign permset --name Item_Purchase_Manager --target-org item-purchase-dev --on-behalf-of manager@example.com
```

Для менеджера также установите `User.IsManager__c = true`. Один permission set не заменяет этот business flag: сервер проверяет оба уровня доступа.

```powershell
sf data update record --sobject User --record-id <USER_ID> --values "IsManager__c=true" --target-org item-purchase-dev
```

### 3. Получатели складских уведомлений

1. Откройте Setup → Custom Settings.
2. Выберите `Inventory Notification Settings` → Manage.
3. Создайте Organization Default Value.
4. В `Recipient User ID` укажите 18-символьный Id активного User.
5. В `Recipient Email` укажите email получателя.

Hierarchy позволяет при необходимости переопределить значения на уровне Profile или User.

### 4. Admin user для проверяющего

В Developer org откройте Setup → Users → New User и создайте активного пользователя с:

- Email: `dev@truesolv.com`;
- User License: Salesforce;
- Profile: System Administrator;
- уникальным глобальным Username;
- включённой отправкой письма с временным паролем.

## Использование

1. Откройте App Launcher → Item Purchase.
2. Создайте или откройте Account.
3. На Account layout нажмите `Item Purchase Tool`.
4. Найдите товары, добавьте их в Cart и выполните Checkout.
5. После успеха Salesforce откроет стандартную Purchase layout с Purchase Lines.
6. Для создания Item войдите менеджером, у которого установлены оба permission sets и `IsManager__c`.

## Automation

| Flow                                 | Trigger                                        | Результат                                |
| ------------------------------------ | ---------------------------------------------- | ---------------------------------------- |
| `Purchase_Line_Totals_After_Save`    | PurchaseLine create/update, after save         | Пересчитывает итоги текущего Purchase    |
| `Purchase_Line_Totals_Before_Delete` | PurchaseLine delete, before delete             | Пересчитывает итоги без удаляемой строки |
| `Notify_When_Item_Out_Of_Stock`      | Item update, quantity changed to 0, after save | Bell и email из Hierarchy Custom Setting |

Bell notification:

- Title: `Item Out of Stock`;
- Message: `The item "{Item Name}" is out of stock. Please review inventory and take the necessary action.`

Email использует template `Out of Stock Item Notification`. Apex action готовит сообщения по шаблону и передаёт их в один `Messaging.sendEmail` call, чтобы не расходовать governor limit на каждую запись отдельно.

## Безопасность и целостность

- все entry-point и service-классы работают `with sharing`;
- пользовательские запросы и Item creation DML используют `WITH USER_MODE`/`AccessLevel.USER_MODE`;
- system mode ограничен созданием Purchase/Lines через защищённый checkout, пересчётом итогов, складским decrement и чтением заранее настроенного email template;
- базовый permission set не даёт прямой Create/Edit на Purchase и PurchaseLine, поэтому API или related list не обходят серверную цену и stock decrement;
- профили прикладных пользователей также не должны давать эти права, поскольку permission set не умеет их отнимать;
- `Purchase__c` имеет Private OWD, а PurchaseLine наследует доступ от родителя; покупатель видит собственную созданную запись, но не покупки других пользователей;
- manager status повторно проверяется в Apex;
- цена и остаток никогда не принимаются от LWC как доверенные значения;
- `FOR UPDATE` предотвращает overselling при параллельном checkout;
- savepoint обеспечивает атомарный rollback;
- динамический SOQL использует bind variables;
- Access Key хранится в зашифрованном User External Credential;
- permission set менеджера предоставляет только минимальный `Read + View All` к `UserExternalCredential`;
- CSP разрешает изображения только с `https://images.unsplash.com`;
- delete для Item пользователям не выдаётся, поскольку dual Master-Detail может каскадно удалить исторические Purchase Lines.

## Проверки качества

```powershell
pnpm format:verify
pnpm lint
pnpm test:unit
pnpm test:unit:coverage
```

Текущий локальный результат:

- 6 Jest suites, 19 tests — passed;
- ESLint — passed;
- Prettier — passed;
- source-based и manifest-based Salesforce conversion — passed, включая email folder/template;
- 23 Apex test methods подготовлены без `SeeAllData=true`.

Локальный parser и source conversion не заменяют server-side compile. Окончательная проверка выполняется `sf apex run test` в целевой org.

GitHub Actions запускает install, formatting check, ESLint и Jest при push в `main` и для pull request.

## Delivery

| Результат                          | Текущий статус                                                                |
| ---------------------------------- | ----------------------------------------------------------------------------- |
| GitHub repository URL              | Не опубликован: локальный remote отсутствует, GitHub CLI не установлен        |
| Email с repository URL             | Не отправлен до появления фактического GitHub URL                             |
| Dev Org deployment                 | Не выполнен: в CLI и браузере нет авторизованной Salesforce org               |
| Admin `dev@truesolv.com`           | Создаётся в целевой org после авторизации                                     |
| Unmanaged package installation URL | Создаётся после успешного deployment, server tests и Upload в Package Manager |

## Unmanaged package

После успешного deployment и server-side tests:

1. Откройте Setup → Package Manager.
2. Создайте package `Item Purchase Tool` без namespace.
3. Добавьте Apex classes, custom objects/fields, LWC bundles, Flows, app, tab, FlexiPage, Account button/layout, permission sets, Custom Setting, email template/folder, Custom Notification Type, CSP Trusted Site, Named Credential и External Credential.
4. Проверьте автоматически добавленные dependencies.
5. Нажмите Upload и сохраните installation URL.

Access Key и записи Hierarchy Custom Setting не входят в package и настраиваются в каждой установленной org отдельно. Unmanaged package не поддерживает upgrades; повторное распространение выполняется новым package или source deployment.

## Принятые решения и ограничения

- `Description__c` — Text(255), а не Long Text Area, чтобы требуемый поиск Name/Description работал через SOQL `LIKE`.
- Значения Type и Family заданы проектом, поскольку техническое задание не определяет наборы picklist.
- Каталог ограничен 500 результатами на запрос; счётчик показывает именно выведенные записи.
- Checkout принимает не более 100 входных строк и пока не использует idempotency key для сетевого повтора запроса.
- Числовые цены отображаются в USD в соответствии с макетом; поля модели остаются Number, как указано в задании.
- `Account-Account Layout` предназначена для чистой Developer org. В существующей org deployment одноимённой layout может заменить её кастомизацию; перед установкой следует retrieve и merge.
- Account button использует стандартный `newWindow`; конкретный браузер может открыть новую вкладку или окно.
- Secret и Custom Setting values не версионируются и не упаковываются.

## Troubleshooting

| Симптом                                | Проверка                                                                                             |
| -------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| Create item возвращает ошибку Unsplash | Principal `Unsplash_Principal` настроен, Access Key активен, менеджеру назначены оба permission sets |
| Create item не видна                   | `User.IsManager__c = true` и назначен `Item_Purchase_Manager`                                        |
| Checkout disabled                      | Страница открыта кнопкой с Account и Cart не пуст                                                    |
| Checkout сообщает insufficient stock   | Обновите каталог; серверный остаток изменился после добавления в Cart                                |
| Bell не приходит                       | Recipient User ID имеет 18 символов, User активен, Custom Notification Type развёрнут                |
| Email не приходит                      | Recipient Email заполнен, Deliverability разрешает отправку, template доступен                       |
| На Account нет кнопки                  | Проверьте назначенную пользователю Account layout и custom button                                    |
| Apex tests не стартуют                 | Выполните org authentication и убедитесь, что metadata уже deployed                                  |

## Дополнительное объяснение

Пошаговый разбор решений, стека и порядка чтения исходников находится в [EXPLAIN.md](EXPLAIN.md).

## Документация Salesforce

- [Apex Security and User Mode](https://developer.salesforce.com/docs/platform/lwc/guide/apex-security)
- [Named Credentials](https://developer.salesforce.com/docs/platform/named-credentials/guide/get-started.html)
- [Populate External Credential Principals](https://developer.salesforce.com/docs/platform/named-credentials/guide/nc-populate-external-credentials.html)
- [LWC Jest Testing](https://developer.salesforce.com/docs/platform/lwc/guide/testing.html)
- [Apex Row Locking](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_locking_statements.htm)
- [Summer '26 / API 67.0](https://developer.salesforce.com/blogs/2026/06/the-salesforce-developers-guide-to-the-summer-26-release)

## License

Отдельная лицензия в репозитории не предоставлена. Проект подготовлен как техническое задание; права использования определяются владельцем репозитория.
