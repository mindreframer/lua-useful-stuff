-- TODO: This should properly support caching for cacheable urls etc.

api:url_with_dynamic_output_format "/multiquery"
{
  doc:description [[Выполнить последовательно несколько запросов]]
  [[
    Запросы выполняются в порядке перечисления.

    URL-ы запросов задаются без форматного префикса `config.<format>_query_url`
    (пример: не ${/:xml/register}, но ${/:register}). Формат выдачи определяется
    форматным префиксом самого запроса ${/:multiquery}.
  ]];

  api:input
  {
    input:LIST "queries"
    {
      input:LIST_NODE "query"
      {
        input:CLIENT_API_QUERY_URL "url";
        input:CLIENT_API_QUERY_PARAM "param";
      };
    };

    doc:comment
    [[
      Пример:

      Два запроса, ${/:resources/flash/list} без параметров
      и ${/:game/money/rates} с параметром `p=1`.
      (Для читаемости запрос разбит на несколько строк.)

      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

          queries[size]=2
          &queries[1][url]=%2fresources%2fflash%2flist
          &queries[1][param]=
          &queries[2][url]=%2fgame%2fmoney%2frates
          &queries[2][param]=p%3d1

      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ]];
  };

  api:dynamic_output_format
  {
    doc:comment
    [[
      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {.xml}

        <results>
            <reply id="${T:INTEGER}">
                <data>
                    [Ответ запроса с указанным номером]
                </data>
            </reply>
            ...
        </results>

      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ]];
  };

  api:additional_errors
  {
    doc:comment
    [[
      Может быть отдана любая из стандартных ошибок (кроме
      ${!:SESSION_EXPIRED}).

      Ошибка ${!:BAD_INPUT} отдаётся также в том случае, если URL одного из
      перечисленных запросов неизвестен.

      Ошибки выполнения отдельных запросов отдаются внутри соответствующих тегов
      `<reply />`.

      Если один из запросов выполнился с ошибкой, выполнение запросов
      **не прекращается**.

      **Примеры:**

      1. Ошибка выполнения первого запроса в списке:

      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {.xml}

          <results>
              <reply id="1">
                  <error id="SESSION_EXPIRED" />
              </reply>
          </results>

      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

      2. Ошибка выполнения самого запроса ${/:multiquery}:

      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {.xml}

          <error id="BAD_INPUT"/>

      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ]];
  };

--------------------------------------------------------------------------------

  api:dynamic_output_format_handler (function(
      output_format_manager,
      output_format_builder,
      api_context,
      param
    )

    local queries = param.queries

    local reply_formats = { }
    local replies = { }

    for i = 1, #queries do
      local query = queries[i]

      local res, err, err_id = api_context:handle_url(query.url, query.param)
      if not res then
        log_error(
            "query", i, query.url, "failed:", err, err_id or "(no err_id)"
          )
        reply_formats[i] = output_format_builder:node (i, "reply")
        {
          output_format_builder:attribute "id";
          -- Note this does not match with standard Luabins error format.
          output_format_builder:node "error"
          {
            output_format_builder:attribute "id";
          };
        }
        replies[i] =
        {
          id = i;
          error =
          {
            id = err_id or "INTERNAL_ERROR";
          }
        }
      else
        reply_formats[i] = output_format_builder:node (i, "reply")
        {
          output_format_builder:attribute "id";
          output_format_builder:node "data"
          {
            -- TODO: Try to cache this!
            try(
                "INTERNAL_ERROR",
                output_format_manager:build_url_output_format(
                    query.url,
                    output_format_builder
                  )
              );
           }
        }

        replies[i] =
        {
          id = i;
          data = res;
        }
      end
    end

    local output_formatter = try(
        "INTERNAL_ERROR",
        output_format_builder:commit(
            output_format_builder:node (nil, "results") (
                reply_formats
              )
          )
      )

    return try("INTERNAL_ERROR", output_formatter(replies))

  end);

--------------------------------------------------------------------------------

}
