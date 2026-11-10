// 사용법: luau-check <테스트.luau> [문법만 검사할 파일.luau ...]
// 첫 파일은 실행하고, 나머지는 컴파일만 해 본다.
// 테스트에는 loadmodule(path) 전역을 제공한다: 파일을 컴파일해 함수로 돌려준다.
use mlua::{Function, Lua, Result};

fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let lua = Lua::new();
    let loadmodule = lua.create_function(|lua, path: String| -> Result<Function> {
        let source = std::fs::read_to_string(&path).map_err(mlua::Error::external)?;
        lua.load(source).set_name(path).into_function()
    })?;
    lua.globals().set("loadmodule", loadmodule)?;

    for path in &args[1..] {
        let source = std::fs::read_to_string(path).map_err(mlua::Error::external)?;
        lua.load(source).set_name(path.as_str()).into_function()?;
        println!("문법 OK: {path}");
    }
    let source = std::fs::read_to_string(&args[0]).map_err(mlua::Error::external)?;
    lua.load(source).set_name(args[0].as_str()).exec()
}
