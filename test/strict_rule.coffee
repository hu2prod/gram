assert = require 'assert'
util = require 'fy/test_util'

strict_rule = require '../strict_rule'
Node = strict_rule.Node
strict_rule_parser = strict_rule.strict_rule_parser
mx_rule_parser = strict_rule.mx_rule_parser
mx_node = strict_rule.mx_node


describe 'strict_rule_parser section', ()->
  it 'works', ()->
    list = [
      '#a'
      '#a[1]'
      '#a[1][1:2]'
      '$1==1'
      '$1==$2'
      '$1+$2'
      '$1|$2'
    ]
    for v in list
      strict_rule_parser.parse v
    return
  
  it 'check', ()->
    t = strict_rule_parser.parse '$1==one'
    assert.ok t.check [new Node 'one']
    assert.ok !t.check [new Node 'two']

describe 'max_rule_parser section', ()->
  it 'works', ()->
    list = [
      'r' # autoassign
      'r=1'
      '@r=1'
      'r=#a'
      'r=#a[1]'
      'r=#a[1][1:2]'
      'r=$1==1'
      'r=$1==$2'
      'r=$1+$2'
      'r=$1|$2'
      'a=1 b=2'
    ]
    for v in list
      mx_rule_parser.parse_as_arr v
    return
  
  it 'mx_key=1', ()->
    res = mx_node mx_rule_parser.parse_as_arr("mx_key=1")
    assert.equal res.mx_hash.mx_key, '1'
    return
  
  it 'mx_key=$1.some_key', ()->
    res = mx_node mx_rule_parser.parse_as_arr("mx_key=$1.some_key"), [new Node('foo', some_key : 'check_value')]
    assert.equal res.mx_hash.mx_key, 'check_value'
    return
  
  it 'autoassign', ()->
    res = mx_node mx_rule_parser.parse_as_arr("autoassign"), [new Node('foo', autoassign : 'a_value')]
    assert.equal res.mx_hash.autoassign, 'a_value'
    return
  
  it 'penetration', ()->
    node_with_penetration = new Node('foo', penetration: 'penetration_value')
    node_with_penetration.penetration_hash['penetration'] = 1
    node = mx_node({},[node_with_penetration])
    assert.equal node.mx_hash['penetration'], 'penetration_value'
    return
  
  it 'penetration conflict', ()->
    node1_with_penetration = new Node('foo', penetration: 'penetration_value')
    node1_with_penetration.penetration_hash['penetration'] = 1
    node2_with_penetration = new Node('foo', penetration: 'penetration_value')
    node2_with_penetration.penetration_hash['penetration'] = 1
    util.throws ()->
      node = mx_node({},[node1_with_penetration,node2_with_penetration])
    , /penetration flag 'penetration' conflict/
    return
  
  