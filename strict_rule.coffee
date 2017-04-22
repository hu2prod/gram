module = @
class @Node
  mx_hash     : {}
  penetration_hash: {}
  value       : ''
  value_array   : []
  constructor   : (value = '', mx_hash = {})->
    @mx_hash    = mx_hash
    @value      = value
    @penetration_hash= {}
    @value_array  = []
  cmp       : (t) ->
    for k,v of @mx_hash
      return false if v != t.mx_hash[k]
    return false if @value != t.value
    # penetration_hash ?
    true
  name : (name)->
    ret = []
    for v in @value_array
      ret.push v if v.mx_hash.hash_key == name
    ret
  str_uid : ()->
    "#{@value} #{JSON.stringify @mx_hash}"
  clone : ()->
    ret = new module.Node
    for k,v of @
      continue if typeof v == 'function'
      ret[k] = clone v unless ret[k] == v
    ret
# ###################################################################################################

class @Strict_rule
  signature      : ''
  position_type   : null
  value       : null
  left      : null # bin_op/un_op
  right       : null # bin_op
  slice       : null
  number_access   : null
  child_access  : null # means mx access
  constructor   : (hash)->
    for k,v of hash
      @[k] = v
  
  clone : ()->
    ret = new module.Strict_rule
    for k,v of @
      continue if typeof v == 'function'
      ret[k] = clone v unless ret[k] == v
    ret
  compile     : ()-># >>>
  intelligent_type_cast: (t)->
    parsed = parseFloat t
    if parsed.toString() == t then parsed else t
  check       : (pos_env = [])-> # интерпретатор
    if @position_type == 'bin_op'
      left  = @intelligent_type_cast @left .check pos_env
      right = @intelligent_type_cast @right.check pos_env
      return left ==  right if @value == '='   or @value == '=='
      return left !=  right if @value == '!='  or @value == '<>'
      return left and right if @value == 'and' or @value == '&'  or @value == '&&'
      return left or  right if @value == 'or'  or @value == '|'  or @value == '||'
      return left  +  right if @value == '+'
      return left  -  right if @value == '-'
      return left  *  right if @value == '*'
      return left  <  right if @value == '<'
      return left  <= right if @value == '<='
      return left  >  right if @value == '>'
      return left  >= right if @value == '>='
      throw new Error "invalid bin_op #{@value}"
    else if @position_type == 'pre_op'
      left  = @left.check pos_env
      return left if @value == 'dummy' or @value == 'none'
      return !left if @value == '!'
      throw new Error "invalid pre_op #{@value}"
    else if @position_type == '$position'
      selected = pos_env[@value-1]
      throw new Error "$position '#{@value}' not exists" if !selected?
      if @child_access
        ret = selected.mx_hash[@child_access]
      else
        ret = selected.value # Node.value
      ret = ret.substr(@slice[0], @slice[1]-@slice[0]+1) if @slice
      return ret
    else if @position_type == 'constant'
      return false if @value == '0'
      return @value
    else
      throw new Error "invalid position_type #{@position_type}"
  get_affected_position_list : (name_env = {}, console_log = true)->
    if @position_type == 'pre_op'
      return @left.get_affected_position_list name_env, console_log
    else if @position_type == '$position'
      return [@value - 1]
    # else if @position_type == 'constant'
    else if @position_type == 'bin_op'
      left = @left.get_affected_position_list  name_env, console_log
      right= @right.get_affected_position_list name_env, console_log
      res = []
      for v in left
        res.push v
      for v in right
        res.push v
      return res
      
    return []
  get_actual_signature : ()->
    if @position_type == 'bin_op'
      left  = @left .get_actual_signature()
      right = @right.get_actual_signature()
      return "#{left}#{@value}#{right}"
    else if @position_type == 'pre_op'
      left  = @left.get_actual_signature()
      return left if @value == 'dummy' or @value == 'none'
      return "#{@value}#{left}"
    else if @position_type == '$position'
      selected = "$#{@value}"
      selected = "#{selected}.#{@child_access}" if @child_access
      selected = "#{selected}[#{@slice[0]}:#{@slice[1]}]" if @slice
      return selected
    else if @position_type == 'constant'
      return @value
    else
      throw new Error "invalid position_type #{@position_type}"
  rebuild_signature : ()->
    @signature = @get_actual_signature()
  optimize_run : (pos_env = [], name_env = {})->
    if @position_type == 'bin_op'
      @left.optimize_run  pos_env, name_env
      @right.optimize_run pos_env, name_env
    else if @position_type == 'pre_op'
      @left.optimize_run  pos_env, name_env
    else if @position_type == '$position'
      # nothing
    else if @position_type == '#position'
      selected = name_env[@value]
      throw new Error "#position '#{@value}' not exists" if !selected?
      if @number_access?
        selected = selected[@number_access-1]
        throw new Error "#position '#{@value}'[#{@number_access}] not exists" if !selected?
      else
        selected = selected[0]
      @position_type = '$position'
      @value = selected.position + 1
    else if @position_type == 'constant'
      # nothing
    else
      throw new Error "invalid position_type #{@position_type}"
    return
    
# ###################################################################################################

class Strict_rule_parser
  string    : ''
  parse_as_arr : (str_list, special_handlers = [])->
    ret = []
    skip = false
    for v in str_list.split ' '
      continue if v == ''
      for handler in special_handlers
        if skip = handler v
          break
      continue if skip
      ret.push @parse v
    ret
  parse_as1 : (str_list)->
    ret = null
    for v in str_list.split ' '
      continue if v == ''
      loc = @parse v
      if ret == null
        ret = loc
        continue
      ret = new module.Strict_rule
        position_type  : 'bin_op' 
        value      : 'and'
        left       : ret
        right      : loc
      
    if ret == null
       ret = new module.Strict_rule
        position_type   : 'constant'
        value       : true
    ret.signature = str_list
    ret
  parse     : (string)->
    @string = string
    
    left = @parse_position()
    if @string == ''
      left.signature = string
      return left 
    
    bin_op = @parse_bin_op()
    throw new Error "bin_op expected" if !bin_op
    
    right  = @parse_position()
    throw new Error "position expected after bin_op" if !bin_op
    
    bin_op.left   = left
    bin_op.right  = right
    bin_op.signature   = string
    bin_op
  regex     : (regex)->
    ret = regex.exec(@string)
    return null if !ret
    @string = @string.substr(ret[0].length)
    ret
  parse_position : ()->
    merge_position = ret = @parse_pre()
    if !ret # wrapper
      merge_position = ret = new module.Strict_rule
        position_type : 'pre_op'
        value  : 'none'
        left   : null
    else
      while merge_position.left
        merge_position = merge_position.left
    loop
      reg_ret = @regex(/^([$#])([_\wа-яА-ЯёЁ][_\wа-яА-ЯёЁ\d]*)/)
      if reg_ret
        merge_position.left = new module.Strict_rule
          position_type   : reg_ret[1]+'position'
          value       : reg_ret[2]
        if reg_ret[1] == '#'
          reg_ret = @regex(/^\[(\d+)\]/)
          merge_position.left.number_access = reg_ret[1] if reg_ret
        
        reg_ret = @regex(/^\[(-?\d+):(-?\d+)\]/)
        merge_position.left.slice = [parseInt(reg_ret[1]), parseInt(reg_ret[2])] if reg_ret
        
        reg_ret = @regex(/^\.([_\wа-яА-ЯёЁ][_\wа-яА-ЯёЁ\d]*)/)
        merge_position.left.child_access = reg_ret[1] if reg_ret
        break
      reg_ret = @regex(/^\"([^\"]*)\"/)
      if !reg_ret
        reg_ret = @regex(/^\'([^\']*)\'/)
      if !reg_ret
        reg_ret = @regex(/^(\d*\.\d+|\d+)/) # float/int
      if !reg_ret
        reg_ret = @regex(/^(.*)/) # other constants
      
      if reg_ret
        merge_position.left = new module.Strict_rule
          position_type   : 'constant'
          value       : reg_ret[1]
        break
      
      throw new Error "must be identifier or string in rule"
    ret
  parse_bin_op: ()->
    ret = @regex(/^(==?|!=|<>|<=?|>=?|\||\-|\+|\*)/)
    return null if !ret
    return new module.Strict_rule
      position_type   : 'bin_op'
      value       : ret[0]
      left      : null
      right       : null
    
  parse_pre   : ()->
    ret = @regex(/^[!]/)
    return null if !ret
    return new module.Strict_rule
      position_type   : 'pre_op'
      value       : ret[0]
      left      : @parse_pre()
    
@strict_rule_parser = new Strict_rule_parser
# console.log @strict_rule_parser
# ###################################################################################################
# mx_rule слишком мелкий, потому его засунем прямо сюда
class @Mx_rule
  name      : null
  penetration_flag: false
  autoassign    : false
  value       : null
  constructor   : (hash)->
    for k,v of hash
      @[k] = v

class Mx_rule_parser
  parse_as_arr : (str_list, special_handlers = [])->
    ret = {}
    skip = false
    for v in str_list.split ' '
      continue if v == ''
      for handler in special_handlers
        if skip = handler v
          break
      continue if skip
      rule = @parse v
      ret[rule.name] = rule
    ret
  parse : (v)->
    if penetration_flag = v[0] == '@'
      v = v.substr 1
    autoassign = v.indexOf('=') == -1
    value = null
    if !autoassign
      [name, value] = v.split('=')
      if /^[\#\$]/.test(value)
        value = module.strict_rule_parser.parse value
      else
        value = new module.Strict_rule
          position_type   : 'constant'
          value       : value
    else
      name = v
      
    new module.Mx_rule
      name        : name
      penetration_flag  : penetration_flag
      autoassign      : autoassign
      value         : value
@mx_rule_parser = new Mx_rule_parser
@mx_node = (mx_hash, pos_env = [], opt = {})->
  ret = new module.Node
  for k,v of mx_hash
    if v.autoassign
      for pos in pos_env
        if pos.mx_hash[k]?
          ret.mx_hash[k] = pos.mx_hash[k]
          break
    else
      ret.mx_hash[k] = v.value.check pos_env
    ret.penetration_hash[k] = 1 if v.penetration_flag
  
  for k,v of ret.mx_hash
    ret.mx_hash[k] = 0 if v == undefined
  
  penetration_hash = {}
  for pos in pos_env
    for k,skip of pos.penetration_hash
      continue if ret.mx_hash[k]?
      if penetration_hash[k]?
        puts pos_env
        puts opt.signature
        throw new Error "penetration flag '#{k}' conflict mx='#{JSON.stringify mx_hash}'"
      penetration_hash[k] = pos.mx_hash[k]
  # if h_count penetration_hash # DEBUG
  #   puts global.mx_node_rule
  #   puts penetration_hash
  for k,v of penetration_hash
    ret.mx_hash[k]      = v
    ret.penetration_hash[k] = 1 unless mx_hash[k]? and !mx_hash[k].penetration_flag
  ret
