api:cacheable_url "/config"
{
  doc:description [[Получить конфигурацию]]
  [[
    Первый запрос при загрузке клиента.

    Доступны также ${/:xml/config} и ${/:json/config}.
  ]];

  urls = -- TODO: ?! Why does this need custom format?
  {
    { url = "/config", format = "xml" };
    { url = "/json/config", format = "json" };
    { url = "/xml/config", format = "xml" };
    { url = "/luabins/config", format = "luabins" };
    { url = "/iframe", format = "xml" };
    { url = "/json/iframe", format = "json" };
    { url = "/xml/iframe", format = "xml" };
    { url = "/luabins/iframe", format = "luabins" };
  };

  api:input { };

  api:output
  {
    output:ROOT_NODE "config"
    {
      output:TIMESTAMP "server_time"
      {
        doc:description [[Текущее время на сервере]]
        [[
          Клиент должен ориентироваться на это время для выполнения действий,
          завязанных на время на сервере (например, ежесуточное обновление
          статистики). Нужно учитывать, что время на клиентской машине может
          "плавать", текущее время на сервере необходимо регулярно (например,
          раз в 10 минут) обновлять при помощи ${/:session/check}.
        ]];
      };

      output:NODE "client"
      {
        output:API_VERSION "api_version";
        output:SESSION_TTL "session_ttl";

        output:ABSOLUTE_URL "xml_query_url"
        {
          doc:description [[Префикс для URL-ов всех запросов XML API]]
          [[
            Например: http://example.com/path/xml, получаем
            http://example.com/path/xml/session/get/.

            Сервер ответит на запрос в формате XML.
          ]];
        };

        output:ABSOLUTE_URL "json_query_url"
        {
          doc:description [[Префикс для URL-ов всех запросов JSON API]]
          [[
            Например: http://example.com/path/json, получаем
            http://example.com/path/json/session/get/.

            Сервер ответит на запрос в формате JSON.
          ]];
        };

        output:RESOURCE_ID "logic_resource_id";
        output:RESOURCE_ID "gfx_resource_id";
        output:RESOURCE_ID "fonts_resource_id";
        output:ABSOLUTE_URL "resources_url";
      };

    };
  };

  api:additional_errors { };

  api:handler (function(api_context, param)
    fail("NOT_IMPLEMENTED", "TODO: Implement")
  end);
}
