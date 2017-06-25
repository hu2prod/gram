assert = require 'assert'
util = (require 'fy').test_util

{
  Gram_cache
  Super_serializer
  Tokenizer
  Token_parser
  Gram
} = require '../src/index'

ss = new Super_serializer
ss_test = (t)->
  ss.deserialize ss.serialize t
assert_string_equal = (a,b)->
  assert.equal a.toString(), b.toString()

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
      util.json_eq t=[null], ss_test t
    it "[true,false,null,'a','1',1,/a/]", ()->
      util.json_eq t=[true,false,null,'a','1',1,/a/], ss_test t
    it 'loop', ()->
      a = []
      a.push a
      t = ss_test a
      assert.ok t == t[0]
  
  describe 'Super_serializer hash', ()->
    it '{a:1}', ()->
      util.json_eq t={a:1}, ss_test t
    it '{a:null}', ()->
      util.json_eq t={a:null}, ss_test t
    it 'loop', ()->
      a = {}
      a['loop'] = a
      t = ss_test a
      assert.ok t == t['loop']
  
  describe 'Super_serializer extreme cases', ()->
    it 'regexp', ()->
      assert_string_equal t=/1/, ss_test t
  
  describe 'Work with gram', ()->
    tok = new Tokenizer
    tok.parser_list.push new Token_parser 'id', /^[_a-z][_a-z0-9]*/i
    tok.parser_list.push new Token_parser 'bin_op', /^[\+\-\*\/]/
    tok.parser_list.push new Token_parser 'un_op', /^(\+\+|\-\-)/
    tok.parser_list.push new Token_parser 'bra', /^[\(\)]/
    
    gram = new Gram
    gram.rule('bin_op',  '*|/|%')               .mx('priority=5 ult=value')
    gram.rule('bin_op',  '+|-')                 .mx('priority=6 ult=value')
    
    gram.rule('pre_op',   '+|-')                .mx('ult=value priority=1')
    gram.rule('post_op',  '++|--')              .mx('ult=value priority=1')

    base_priority = -9000
    gram.rule('expr',  '( #expr )')             .mx("priority=#{base_priority} ult=deep")
    gram.rule('expr',  '#pre_op #expr')         .mx("priority=1 ult=pre_op")  .strict('#expr.priority<#pre_op.priority')
    gram.rule('expr',  '#expr #post_op')        .mx("priority=1 ult=post_op") .strict('#expr.priority<#post_op.priority')

    gram.rule('expr',  '#expr #bin_op #expr')   .mx('priority=#bin_op.priority ult=bin_op').strict('#expr[1].priority<#bin_op.priority #expr[2].priority<#bin_op.priority')
    gram.rule('expr',  '#expr #bin_op #expr')   .mx('priority=#bin_op.priority ult=bin_op').strict('#expr[1].priority<#bin_op.priority #expr[2].priority=#bin_op.priority #bin_op.left_assoc')

    gram.rule('expr',  '#id')                   .mx('priority=-9000 ult=value')
    cache = new Gram_cache()
    opt = {
      cache_deserialize : cache.get_cache_serialize()
      cache_serialize   : cache.get_cache_deserialize()
    }
    parse = (t)->
      gram.parse_text_list(tok.go(t), opt)[0]
    parse "a+(b+c)"
    parse "d+(b+c)"
    