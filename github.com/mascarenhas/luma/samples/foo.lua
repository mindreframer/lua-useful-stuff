module("foo", package.seeall)

class_description [[
  extends bar

  class method baz(x, y)
    return x + y
  end

  print("Bah! Humbug")

  instance method say(x)
    if self.message then
      return self.message .. " " .. x
    else
      return x
    end
  end

  instance method initialize(msg)
    super.initialize(self, msg)
  end
]]
