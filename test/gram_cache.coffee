assert = require 'assert'
util = require 'fy/test_util'

gram_cache = require '../gram_cache'
Super_serializer = gram_cache.Super_serializer

ss = new Super_serializer
ss_test = (t)->
  ss.deserialize ss.serialize t
assert_string_equal = (a,b)->
  assert.equal a.toString(), b.toString()
assert_json_equal = (a,b)->
  assert.equal JSON.stringify(a), JSON.stringify(b)
describe 'Gram_cache module', ()->
  describe 'Super_serializer const', ()->
    it 'null',  ()->assert.equal t=null,  ss_test t
    it 'true',  ()->assert.equal t=true,  ss_test t
    it 'false', ()->assert.equal t=false, ss_test t
    it 'int',   ()->assert.equal t=1,     ss_test t
    it 'string',()->assert.equal t="1",   ss_test t
  describe 'Super_serializer array', ()->
    it '[1,2,3]', ()->
      assert_string_equal t=[1,2,3], ss_test t
    it "[null]", ()->
      assert_json_equal t=[null], ss_test t
    it "[true,false,null,'a','1',1,/a/]", ()->
      assert_json_equal t=[true,false,null,'a','1',1,/a/], ss_test t
    it 'loop', ()->
      a = []
      a.push a
      t = ss_test a
      assert.ok t == t[0]
  describe 'Super_serializer hash', ()->
    it '{a:1}', ()->
      assert_json_equal t={a:1}, ss_test t
    it '{a:null}', ()->
      assert_json_equal t={a:null}, ss_test t
    it 'loop', ()->
      a = {}
      a['loop'] = a
      t = ss_test a
      assert.ok t == t['loop']
  describe 'Super_serializer extreme cases', ()->
    it 'regexp', ()->
      assert_string_equal t=/1/, ss_test t
