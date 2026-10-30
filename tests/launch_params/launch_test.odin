package launch_params_test
import "core:testing"
import gd "godot:godot"
@(test)
query_form_spaces_and_literal_plus_keep_uri_path_semantics :: proc(t:^testing.T) {
	query:=gd.query_decode("Browser+1%2BScout%20%F0%9F%AA%A8",context.allocator);defer delete(query)
	testing.expect_value(t,query,"Browser 1+Scout 🪨")
	uri:=gd.uri_decode("Browser+1%2BScout",context.allocator);defer delete(uri)
	testing.expect_value(t,uri,"Browser+1+Scout")
	bad:=gd.query_decode("%bad%2+%ZZ",context.allocator);defer delete(bad)
	testing.expect_value(t,bad,"\xbad%2 %ZZ")
}
