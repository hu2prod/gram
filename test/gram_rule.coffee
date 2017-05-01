assert = require 'assert'
util = require 'fy/test_util'

gram_rule = require '../gram_rule'
Gram = gram_rule.Gram
perf_bench = (gram, string)->
  start = new Date
  res = gram.parse string
  time = (new Date) - start
  assert.equal res.length, 1
  assert.ok time < 100

describe 'gram_rule section', ()->
  it 'simple rules', ()->
    gram = new Gram
    gram.rule('что', 'где когда').mx('var=1').strict('1==1')
    gram.rule('что2','где когда?').mx('var=1').strict('1==1')
    t = gram
    assert.equal t.rule_list.length, 2
  
  it 'n in 1 rules', ()->
    gram = new Gram
    gram.rule('что', 'где когда').mx('var=1').strict('1==1')
    gram.rule('что2','где #когда?').mx('var=1').strict('1==1')
    t = gram
    assert.equal t.rule_list.length, 4
  
  it 'random gen', ()->
    gram = new Gram
    gram.rule('full', 'sample')
    assert.equal gram.gen_random('full').value, 'sample'
  
  it 'sample', ()->
    gram = new Gram
    gram.rule('sample', 'result')
    res = gram.parse 'result'
    res.sort (a,b)-> -a.mx_hash.hash_key.localeCompare b
    
    assert.equal res[0].mx_hash.hash_key, 'base'
    assert.equal res[0].value, 'result'
    assert.equal res[0].value_array[0].value, 'result'
  
  it 'sample proxy', ()->
    gram = new Gram
    gram.rule('proxy', 'result')
    gram.rule('sample', 'proxy')
    res = gram.parse 'result'
    res.sort (a,b)-> -a.mx_hash.hash_key.localeCompare b
    
    assert.equal res[0].mx_hash.hash_key, 'base'
    assert.equal res[0].value, 'result'
    assert.equal res[0].value_array[0].value, 'result'
  
  it 'priority', ()->
    gram = new Gram
    gram.rule('bin_op',  '*|/|%')             .mx('@priority=5')
    gram.rule('bin_op',  '+|-')               .mx('@priority=6')
    
    base_priority = -9000
    gram.rule('expr',  '( #expr )')           .mx("@priority=#{base_priority}")
    
    gram.rule('expr',  '#expr #bin_op #expr') .mx('@priority=#bin_op.priority')       .strict('#expr[1].priority<#bin_op.priority #expr[2].priority<#bin_op.priority')
    gram.rule('expr',  '#expr #bin_op #expr') .mx('@priority=#bin_op.priority')       .strict('#expr[1].priority<#bin_op.priority #expr[2].priority=#bin_op.priority #bin_op.left_assoc')
    
    gram.rule('expr',  'a|b|c')               .mx('@priority=-9000')
    
    res = gram.parse 'a + b'
    assert.equal res.length, 1
    assert.equal res[0].value, 'a + b'
    
    res = gram.parse  'a + b * c'
    assert.equal res.length, 1
    assert.equal res[0].value_array[2].value, 'b * c'
    
    res = gram.parse 'a * b + c'
    assert.equal res.length, 1
    assert.equal res[0].value_array[0].value, 'a * b'
  
  it 'performance', ()->
    base_priority = -9000
    gram = new Gram
    gram.rule('bin_op',  '*|/|%')             .mx('@priority=5 right_assoc=1')
    gram.rule('bin_op',  '+|-')               .mx('@priority=6 right_assoc=1')
    
    gram.rule('expr',  '( #expr )')           .mx("@priority=#{base_priority}")
    
    gram.rule('expr',  '#expr #bin_op #expr') .mx('@priority=#bin_op.priority')       .strict('#expr[1].priority<#bin_op.priority #expr[2].priority<#bin_op.priority')
    gram.rule('expr',  '#expr #bin_op #expr') .mx('@priority=#bin_op.priority')       .strict('#expr[1].priority<#bin_op.priority #expr[2].priority=#bin_op.priority #bin_op.left_assoc')
    gram.rule('expr',  '#expr #bin_op #expr') .mx('@priority=#bin_op.priority')       .strict('#expr[1].priority=#bin_op.priority #expr[2].priority<#bin_op.priority #bin_op.right_assoc')
    
    gram.rule('expr',  'a|b|c')               .mx('@priority=-9000')
    list = [
      'a + a + a'
      'a + a + a + a'
      'a + a + a + a + a'
      'a + a + a + a + a + a'
      'a + a + a + a + a + a + a'
      'a + a + a + a + a + a + a + a'
      'a + a + a + a + a + a + a + a + a + a'
      'a + a + a + a + a + a + a + a + a + a + a + a'
      'a + a + a + a + a + a + a + a + a + a + a + a + a + a'
      'a + a + a + a + a + a + a + a + a + a + a + a + a + a + a + a'
      'a + a + a + a + a + a + a + a + a + a + a + a + a + a + a + a + a + a + a + a + a + a + a + a + a + a + a + a' # (a x28) too stress test i7 -> 56 ms
      'a + a - a + a - a + a - a'
      'a + a * a + a * a + a * a'
    ]
    for v in list
      perf_bench gram, v
    return
  
  
  it 'mixed # and word', ()->
    gram = new Gram
    gram.rule('type3',  'target')
    gram.rule('result', '#type3 postfix') # смешанные случаи # и прямых слов
    
    res = gram.parse 'target postfix'
    assert.equal res.length, 1
    
  
  it '0-cycle', ()->
    gram = new Gram
    gram.rule('type3',  'target')
    gram.rule('type2',  '#type3') # 0-cycle (процесс преобразования не уменьшает количество токенов)
    gram.rule('postfix', 'postfix')
    gram.rule('result', '#type2 #postfix')
    
    res = gram.parse 'target postfix'
    assert res.length, 1
  
  it 'proxy undouble', ()->
    gram = new Gram
    gram.rule('type3',  'target')
    gram.rule('result', '#type3 postfix')
    gram.rule('result', '#unused postfix') # смешанные случаи # и прямых слов случай дублирования proxy_
    
    res = gram.parse 'target postfix'
    assert res.length, 1
  
  it '2 word', ()->
    gram = new Gram
    gram.rule('big_o', 'pos1 pos2')
    res = gram.parse "pos1 pos2"
    assert res.length, 1
  
  it '3 word', ()->
    gram = new Gram
    gram.rule('big_o', 'pos1 pos2 pos3')
    res = gram.parse "pos1 pos2 pos3"
    assert res.length, 1
  
  it '3 word nested', ()->
    gram = new Gram
    gram.rule('big_o', 'pos1 pos2 pos3')
    gram.rule('big_o2', '#big_o pos4')
    res = gram.parse "pos1 pos2 pos3 pos4"
    assert res.length, 1
  
  it 'repeat left', ()->
    gram = new Gram
    gram.rule('multipipe',  'a')
    gram.rule('multipipe',  '#multipipe a')
    res = gram.parse 'a a'
    assert.equal res.length, 1
  
  it 'repeat right', ()->
    gram = new Gram
    gram.rule('multipipe',  'a')
    gram.rule('multipipe',  'a #multipipe')
    res = gram.parse 'a a'
    assert.equal res.length, 1
  
  it 'escaping |', ()->
    gram = new Gram
    gram.rule('multipipe',  '[PIPE]')
    res = gram.parse '|'
    assert.equal res.length, 1
  
  it 'escaping ?', ()->
    gram = new Gram
    gram.rule('multipipe',  '[QUESTION]')
    res = gram.parse '?'
    assert.equal res.length, 1
  
  it 'escaping $', ()->
    gram = new Gram
    gram.rule('multipipe',  '[DOLLAR]')
    res = gram.parse '?'
    assert.equal res.length, 1
  
  it 'escaping #', ()->
    gram = new Gram
    gram.rule('multipipe',  '[HASH]')
    res = gram.parse '?'
    assert.equal res.length, 1
  
  it 'escaping 2', ()->
    gram = new Gram
    gram.rule('multipipe',  '[PIPE] [PIPE]')
    res = gram.parse '| |'
    assert.equal res.length, 1
  
  it 'escaping 3', ()->
    gram = new Gram
    gram.rule('multipipe',  '[PIPE]')
    gram.rule('multipipe',  '#multipipe [PIPE]')
    res = gram.parse '| |'
    assert.equal res.length, 1
  