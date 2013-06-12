-- TODO: Semi-fake, for documentation only. Use for actual schema work as well.
-- TODO: Make it non-fake! (need to make changes to apigen)
-- TODO: Do not hardcode enum values!

-- TODO: add more actual values, remove obsolete or irrelevant
-- TODO: add relevant doumentation texts

io_type:string "SESSION_ID"
{
  min_length = 37;
  max_length = 37;

  doc:description [[Идентификатор игровой (внутренней) сессии]];
}

io_type:integer "ACCOUNT_ID"
{
  doc:description [[Идентификатор аккаунта в игре]];
}

io_type:text "API_VERSION"
{
  doc:description [[Версия клиентского API]]
  [[
    Соответствует версии документа
  ]];
}

io_type:integer "SESSION_TTL"
{
  doc:description [[TTL игровой сессии (в секундах)]];
}

io_type:text "EXTRA_INFO"
{
  doc:description [[Дополнительные данные о пользователе]]
  [[
    В машинно-читаемом виде
  ]];
}

io_type:enum "STAT_EVENT_ID"
{
  doc:description [[Идентификатор события для статистики]]
  [[
    Значения:

        1 — REGISTERED, зарегистрировались
        2 — SECOND_LOGIN, зашли в игру во второй раз
  ]];
}

io_type:integer "DELTA_TIME"
{
  doc:description [[Длительность (в секундах)]];
}

io_type:timestamp "TIMESTAMP"
{
  doc:description [[Дата (по серверу) начала следующей стадии роста растения]];
}

io_type:text "CLIENT_API_QUERY_PARAM"
{
  doc:description [[Данные запроса клиентского API]]
  [[
    Пример: `"p=1&u=42"`.

    Примечание: как и любые другие данные, ${T:CLIENT_API_QUERY_PARAM}
    необходимо экранировать через `urlencode()` при передаче через POST-запрос.
  ]];
}

io_type:integer "POSITIVE_INTEGER"
{
  doc:description [[целое, большее ноля]]
  [[
    Например количество очков, используемых для ранжирования
    (объем дохода, число посетителей и т.д),
    позиция в рейтинге и т.д.
  ]];
}

io_type:integer "PARAMETER_NAME"
{
  doc:description [[модифицируемый параметр]];
}

io_type:string "TEST_SESSION_ID"
{
  min_length = 1;
  max_length = 256;

  doc:description [[Идентификатор сессии у партнёра TODO: это стаб.]];
}
