--------------------------------------------------------------------------------
-- yandex.lua
-- This file is a part of pk-billing-lib library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

api:export "lib/paysystems/lib/yandex"
{
  exports =
  {
    --data
    "YA_MD5HASH_FIELDS";

    "YA_ERROR_CODES";

    --methods
    "ya_create_hash";
    "ya_create_response";
    "ya_build_response";
  };

  handler = function()
    local YA_ERROR_CODES =
    {
      ["OK"] = 0;
      ["BAD_INPUT"] = 200;
      ["WAIT_FOR_RESULT"] = 1000;
      ["INTERNAL_ERROR"] = 1000;
      ["INCORRECT_INPUT"] = 200;
      ["INCORRECT_HASH"] = 1;
      ["DATA_NOT_MATCH"] = 100;
      ["INCORRECT_STATUS"] = 100;
    }
    local YA_MD5HASH_FIELDS =
    {
      "orderIsPaid";
      "orderSumAmount";
      "orderSumCurrencyPaycash";
      "orderSumBankPaycash";
      "shopId";
      "invoiceId";
      "customerNumber";
    }

    local ya_create_hash = function(request, app)
      arguments(
          "table", request,
          "table", app
        )

      app.config = app.config or { }
      if not app.config['ya_shop_password'] then
        return
          nil,
          "Yandex shop password in config app = " .. app.id .. " is absent"
      end

      local md5fields = { }
      for i = 1, #YA_MD5HASH_FIELDS do
        local field = YA_MD5HASH_FIELDS[i]

        if not request[field] then
          return nil, "Field " .. field .. " not found in request"
        end
        md5fields[#md5fields + 1] = tostring(request[field])
      end
      md5fields[#md5fields + 1] = app.config['ya_shop_password']

      md5fields = table.concat(md5fields, ";")

      return md5.sumhexa(md5fields):upper()
    end

    local ya_create_response = function(code, request)
      local currencyTime = os.date("%Y-%m-%dT%H:%M:%S") .. "+04:00"
      local xml = [[<response performedDatetime = "]] .. currencyTime .. [[">
  <result code="]] .. tostring(code)
    .. [[" action="]] .. (tostring(request.action) or "NIL")
    .. [[" shopId="]] .. (tostring(request.shopId) or "NIL")
    .. [[" invoiceId="]] .. (tostring(request.invoiceId) or "NIL")
    .. [[" />
</response>]]

      return xml
    end

    local ya_build_response = function(code, request)
      arguments(
          "string", code,
          "table", request
        )
      code = YA_ERROR_CODES[code] or code
      local body = ya_create_response(code, request)
      return xml_response(body)
    end
  end;
}
