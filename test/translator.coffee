assert = require 'assert'
util = require 'fy/test_util'

g = require '../src/index.coffee'
{Translator, Gram, Tokenizer, Token_parser,
  bin_op_translator_holder, bin_op_translator_framework
  un_op_translator_holder,  un_op_translator_framework
} = g


tok = new Tokenizer
tok.parser_list.push new Token_parser 'id', /^[_a-z][_a-z0-9]*/i
tok.parser_list.push new Token_parser 'bin_op', /^[\+\-\*\/]/
tok.parser_list.push new Token_parser 'un_op', /^(\+\+|\-\-)/
tok.parser_list.push new Token_parser 'bra', /^[\(\)]/




describe 'translator section', ()->
  describe 'deep trans', ()->
    gram = new Gram
    gram.rule('bin_op',  '*|/|%')               .mx('priority=5 ult=value')
    gram.rule('bin_op',  '+|-')                 .mx('priority=6 ult=value')

    base_priority = -9000
    gram.rule('expr',  '( #expr )')             .mx("priority=#{base_priority} ult=deep")

    gram.rule('expr',  '#expr #bin_op #expr')   .mx('priority=#bin_op.priority ult=deep').strict('#expr[1].priority<#bin_op.priority #expr[2].priority<#bin_op.priority')
    gram.rule('expr',  '#expr #bin_op #expr')   .mx('priority=#bin_op.priority ult=deep').strict('#expr[1].priority<#bin_op.priority #expr[2].priority=#bin_op.priority #bin_op.left_assoc')

    gram.rule('expr',  '#id')                   .mx('priority=-9000 ult=value')

    parse = (t)->
      gram.parse_text_list(tok.go(t))[0]

    r = trans = new Translator
    r.trans_skip = {}
    r.trans_value= {}
    deep = (ctx, node)->
      list = []
      if node.mx_hash.deep?
        node.mx_hash.deep = '0' if node.mx_hash.deep == false # special case for deep=0
        value_array = (node.value_array[pos] for pos in node.mx_hash.deep.split ',')
      else
        value_array = node.value_array
      for v,k in value_array
        if r.trans_skip[v.mx_hash.hash_key]?
          list.push "" # nothing
        if r.trans_value[v.mx_hash.hash_key]?
          list.push v.value
        else if /^proxy_/.test v.mx_hash.hash_key
          list.push v.value
        else
          list.push ctx.translate v
      if delimiter = node.mx_hash.delimiter
        list = [ list.join(delimiter) ]
      list

    trans.translator_hash['value']  = translate:(ctx, node)->node.value
    trans.translator_hash['deep']   = translate:(ctx, node)->
      list = deep ctx, node
      list.join('')
    
    it 'a+b', ()->
      ret = trans.go parse "a+b"
      assert.equal ret, "a+b"
    it '(a+b)', ()->
      ret = trans.go parse "(a+b)"
      assert.equal ret, "(a+b)"
    it 'a + b', ()->
      ret = trans.go parse "a + b"
      assert.equal ret, "a+b"
    
  describe 'bin_op_translator_holder/framework trans', ()->
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

    parse = (t)->
      gram.parse_text_list(tok.go(t))[0]

    r = trans = new Translator
    r.trans_skip = {}
    r.trans_value= {}
    deep = (ctx, node)->
      list = []
      if node.mx_hash.deep?
        node.mx_hash.deep = '0' if node.mx_hash.deep == false # special case for deep=0
        value_array = (node.value_array[pos] for pos in node.mx_hash.deep.split ',')
      else
        value_array = node.value_array
      for v,k in value_array
        if r.trans_skip[v.mx_hash.hash_key]?
          list.push "" # nothing
        if r.trans_value[v.mx_hash.hash_key]?
          list.push v.value
        else if /^proxy_/.test v.mx_hash.hash_key
          list.push v.value
        else
          list.push ctx.translate v
      if delimiter = node.mx_hash.delimiter
        list = [ list.join(delimiter) ]
      list
    holder = new bin_op_translator_holder
    for v in bin_op_list = ["+", '-', '*', '/']
      holder.op_list[v]  = new bin_op_translator_framework "($1 $op $2)"
    trans.translator_hash['bin_op'] = holder
    
    holder = new un_op_translator_holder
    holder.mode_pre()
    for v in un_op_list = ["+", '-']
      holder.op_list[v]  = new un_op_translator_framework "($op $1)"
    trans.translator_hash['pre_op'] = holder
    
    holder = new un_op_translator_holder
    holder.mode_post()
    for v in un_op_list = ["++", '--']
      holder.op_list[v]  = new un_op_translator_framework "($1$op)"
    trans.translator_hash['post_op'] = holder

    trans.translator_hash['value']  = translate:(ctx, node)->node.value
    trans.translator_hash['deep']   = translate:(ctx, node)->
      list = deep ctx, node
      list.join('')
    
    it 'a+b', ()->
      ret = trans.go parse "a+b"
      assert.equal ret, "(a + b)"
    
    it 'a + b', ()->
      ret = trans.go parse "a + b"
      assert.equal ret, "(a + b)"
    
    it '+a+b', ()->
      ret = trans.go parse "+a+b"
      assert.equal ret, "((+ a) + b)"
    
    it '+a+b++', ()->
      ret = trans.go parse "+a+b++"
      assert.equal ret, "((+ a) + (b++))"
    
    
  