//------------------------------------------------------------------------------
//  Initialize pk admin library
//------------------------------------------------------------------------------

if (PKAdmin === undefined)
{
  var PKAdmin = new function()
  {
    this.check_namespace = function(name)
    {
      if (this[name] === undefined)
        this[name] = new Object
      return this[name]
    }
  }
}

//TODO: Remove after pk-core-js is included
if (PK !== undefined && PK.clone === undefined)
{
  PK.clone = function(obj)
  {
    if (typeof(obj) != "object" || obj == null)
      return obj

    var clone = obj.constructor()
    for(var i in obj)
      clone[i] = PK.clone(obj[i])
    return clone
  }
}
