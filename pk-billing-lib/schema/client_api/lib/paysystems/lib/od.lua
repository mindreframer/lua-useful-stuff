--------------------------------------------------------------------------------
-- od.lua
-- This file is a part of pk-billing-lib library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

api:export "lib/paysystems/lib/od"
{
  exports =
  {
    --data
    "OD_ERROR_DESCRIPTIONS";

    "OD_CHECK_REQUEST";
    "OD_PAYMENT_REQUEST";

    "OD_RESPONSE_CODE_NO";
    "OD_RESPONSE_CODE_YES";

    --methods
    "od_create_hash";

    "od_build_response";
    "od_create_check_response";
    "od_create_payment_response";
  };

  handler = function()
    local OD_ERROR_DESCRIPTIONS =
    {
      ["BAD_INPUT"] = "Недостаточно входных данных";
      ["INTERNAL_ERROR"] = "Внутренняя ошибка системы";
      ["INCORRECT_AMOUNT"] = "Некорректная сумма оплаты";
      ["INCORRECT_DATA"] = "Внутренняя ошибка системы";
    }
    local OD_CHECK_REQUEST = "check"
    local OD_PAYMENT_REQUEST = "payment"
    local OD_RESPONSE_CODE_NO = "NO"
    local OD_RESPONSE_CODE_YES = "YES"

    local od_create_hash = function(method, request, od_shop_password)
      arguments(
          "string", method,
          "table", request,
          "string", od_shop_password
        )

      local hash = ""
      if method:lower() == "check" then
        hash = "0" .. request.userid .. "0" .. od_shop_password
      elseif method:lower() == "payment" then
        hash = request.amount
          .. request.userid
          .. request.paymentid
          .. od_shop_password
      end

      return md5.sumhexa(hash)
    end

    local od_create_payment_response = function(code, request)
      arguments(
          "string", code,
          "table", request
        )

      local comment = OD_ERROR_DESCRIPTIONS[code]

      code = code ~= OD_RESPONSE_CODE_YES
        and OD_RESPONSE_CODE_NO
        or OD_RESPONSE_CODE_YES

      local cat, concat = make_concatter()
      cat [[<?xml version="1.0" encoding="UTF-8"?>
<result>
  <id>]] (htmlspecialchars(request.transaction_id or request.userid)) [[</id>
  <code>]] (htmlspecialchars(code)) [[</code>]]
      if comment then
        cat [[<comment>]] (htmlspecialchars(comment)) [[</comment>]]
      end
      cat [[</result>]]

      return concat()
    end

    local od_create_check_response = function(code)
      arguments(
          "string", code
        )
      local cat, concat = make_concatter()
      cat [[<?xml version="1.0" encoding="UTF-8"?>
<result>
  <code>]] (htmlspecialchars(code:upper())) [[</code>
</result>]]

      return concat()
    end

    local od_build_response = function(method, code, request)
      arguments(
          "string", method,
          "string", code,
          "table", request
        )
      local body = ""

      if method:lower() == OD_CHECK_REQUEST then
        body = od_create_check_response(code, request)
      elseif method:lower() == OD_PAYMENT_REQUEST then
        body = od_create_payment_response(code, request)
      end
      return xml_response(body)
    end
  end;
}
