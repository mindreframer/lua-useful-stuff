local luarocks_show_rock_dir
      = import 'lua-aplicado/shell/luarocks.lua'
      {
        'luarocks_show_rock_dir'
      }

project_create.root_template_name = "generic"
project_create.root_template_paths =
{
  {
    path = luarocks_show_rock_dir("pk-project-tools.project-templates")
      .. "/src/lua/";
  };
}
