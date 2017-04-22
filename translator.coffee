require 'fy'
module = @

class @Sink_point
  buffer  : []
  namespace : {}
  constructor : ()->
    @buffer   = []
    @namespace  = {}
  push    : (v)-> @buffer.push v
  unshift   : (v)-> @buffer.unshift v
  toStringBlockJS  : ()->
    ret = "\t" + @buffer.join "\n"
    ret.replace /\n/g, "\n\t"
  toString  : ()-> @buffer.join "\n"
# ###################################################################################################
class @bin_op_translator_framework
  template_pre: null
  template  : ''
  constructor : (template, template_pre = null)->
    @template     = template
    @template_pre   = template_pre
  apply_template : (template, ctx, array)->
    list = template.split /(\$(?:1|2|op))/
    for v,k in list
      switch v
        when "$1"
          list[k] = array[0]
        when "$2"
          list[k] = array[2]
        when "$op"
          list[k] = array[1]
    list.join ""
    # херит всё, если в подстановке будет, например, $2
    # template = template.replace /\$1/g, array[0]
    # template = template.replace /\$2/g, array[2]
    # template = template.replace /\$op/g,array[1]
  translate   : (ctx, array)->
    if @template_pre
      ctx.cur_sink_point.push @apply_template @template, ctx, array
    @apply_template @template, ctx, array
class @bin_op_translator_holder
  op_list     : {}
  constructor : ()->
    @op_list      = {}
  translate   : (ctx, node)->
    key = node.value_array[1].value
    throw new Error "unknown bin_op '#{key}' known bin_ops #{Object.keys(@op_list).join(' ')}" if !@op_list[key]?
    left  = ctx.translate node.value_array[0]
    right = ctx.translate node.value_array[2]
    @op_list[key].translate ctx, [ left , key , right ]
# ###################################################################################################
class @un_op_translator_framework
  template_pre: null
  template  : ''
  constructor : (template, template_pre = null)->
    @template     = template
    @template_pre   = template_pre
  apply_template : (template, ctx, array)->
    list = template.split /(\$(?:1|2|op))/
    for v,k in list
      switch v
        when "$1"
          list[k] = array[1]
        when "$op"
          list[k] = array[0]
    list.join ""
    # template = template.replace /\$1/g, array[1]
    # template = template.replace /\$op/g,array[0]
  translate   : (ctx, array)->
    if @template_pre
      ctx.cur_sink_point.push @apply_template @template, ctx, array
    @apply_template @template, ctx, array
class @un_op_translator_holder
  op_list     : {}
  op_position   : 0 # default pre
  left_position   : 1
  constructor : ()->
    @op_list      = {}
  translate   : (ctx, node)->
    key = node.value_array[@op_position].value
    throw new Error "unknown un_op '#{key}' known un_ops #{Object.keys(@op_list).join(' ')}" if !@op_list[key]?
    left  = ctx.translate node.value_array[@left_position]
    @op_list[key].translate ctx, [ key , left ]
  mode_pre  : ()->
    @op_position  = 0
    @left_position  = 1
  mode_post   : ()->
    @op_position  = 1
    @left_position  = 0
# ###################################################################################################
class @Translator
  translator_hash : {}
  sink_point_stack: []
  cur_sink_point  : null
  constructor : ()->
    @translator_hash  = {}
    @reset()
  sink_begin   : ()->
    @sink_point_stack.push @cur_sink_point
    @cur_sink_point = new module.Sink_point
    return
  sink_end  : ()->
    temp = @cur_sink_point.toString()
    @cur_sink_point = @sink_point_stack.pop() 
    @cur_sink_point.push temp
    return
  reset     : ()->
    @cur_sink_point = new module.Sink_point
    @sink_point_stack   = []
  translate   : (node)->
    key = node.mx_hash.ult
    throw new Error "unknown node type '#{key}' mx='#{JSON.stringify node.mx_hash}'" if !@translator_hash[key]?
    @translator_hash[key].translate @, node
  # really public
  trans   : (node)->
    @reset()
    @cur_sink_point.push @translate node
    @cur_sink_point.toString()
  go    : (node)->
    @trans node
# 
