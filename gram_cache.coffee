fs = require 'fs'

module = @
class @Super_serializer
  ref_obj_root  : [] # temp for build
  obj_root    : []
  constructor:()->
    @ref_obj_root = []
    @obj_root = []
  
  class_serialize   : (t)->
    if t instanceof RegExp
      ret =
        _class : 'RegExp'
        toString: t.toString()
    else if t instanceof Array
      ret = {} # Внезапно
      ret._class = 'Array'
      for v,k in t
        throw new Error("_class exists") if k == '_class'
        throw new Error("can't serialize function in array (no way for ressurect correctly)") if typeof v == 'function'
        ret[k] = v
    else
      ret = {}
      _class = t.constructor.name
      ret._class = _class if _class != 'Object' and _class != false # Array
      for k,v of t
        throw new Error("_class exists") if k == '_class'
        continue if typeof v == 'function'
        ret[k] = v
    ret
  class_deserialize   : (t)->
    if t._class?
      if t._class == 'RegExp'
        [skip, body, tail] = /^\/(.*)\/([a-z]*)$/.exec t.toString
        return new RegExp body, tail
      ret = eval "new #{t._class}"
    else
      ret = {}
    for k,v of t
      continue if k == '_class'
      ret[k] = v
    ret
  
  serialize   : (t)->
    @ref_obj_root   = []
    @obj_root     = []
    
    if typeof t != 'object' or t == null
      @obj_root.push t
    else
      @_serialize t
    @obj_root
  ref   : (t)->
    for v,k in @ref_obj_root
      return "Sref_#{k}" if v == t
    return null
  unref : (id)->@obj_root[id]
  _serialize   : (t)->
    return t if typeof t != 'object' or t == null
    return r if r = @ref t
    
    ret = @ref_obj_root.length
    @ref_obj_root.push t
    cs_t = @class_serialize t
    for k,v of cs_t # по-любому of
      cs_t[k] = @_serialize v
    @obj_root[ret] = cs_t
    "Sref_#{ret}"
  deserialize : (obj)->
    @obj_root = obj
    @ref_obj_root = new Array @obj_root.length # some mem optimize
    
    for v,k in @obj_root
      if typeof v == 'object' and v != null
        @ref_obj_root[k] = @class_deserialize v
      else
        @ref_obj_root[k] = v
    for v,k in @obj_root
      for k2,v2 of v
        if ret = /^Sref_(\d+)$/.exec v2
          @ref_obj_root[k][k2] = @ref_obj_root[ret[1]] # parseInt не обязателен
    @ref_obj_root[0]
      
    
Super_serializer = new @Super_serializer
class @Gram_cache
  file    : ''
  gram_crc  : ''
  gram_hash   : {}
  constructor:()->
  token_serialize : (t)->
    res = {
      value_array : []
      rule : null
      a  : t.a
      b  : t.b
    }
    for v in t.value_array
      if v.serialize_uid?
        res.value_array.push v.serialize_uid
      else if v.serialize_ab_uid?
        res.value_array.push v.serialize_ab_uid
      else
        puts v
        throw new Error("missing token.serialize_uid and token.serialize_ab_uid") 
    if !t.rule.serialize_uid?
      puts t.rule
      throw new Error("missing t.rule.serialize_uid") 
        
    res.rule = {
      len: t.rule.serialize_length
      uid: t.rule.serialize_uid
    }
    res
  get_cache_serialize : ()->
    (gram, list)=>
      @gram_hash = {
        token_list : []
        merge_history : []
      }
      gram.rule_enumerate()
      gram.token_enumerate()
      for v in gram.merge_history
        @gram_hash.merge_history.push @token_serialize v
      for v in gram.token_list
        @gram_hash.token_list.push v[0].value
      return
  get_cache_deserialize : ()->
    (gram, list)=>
      return if !@gram_hash.token_list?
      # build 3-token value map
      cache_token_value_length = 3
      token_value_map = {} # {[]}
      arr = @gram_hash.token_list
      (()-># защитим отечество, защитим scope
        for i in [0 .. arr.length-cache_token_value_length]
          key_arr = []
          for pos in [i ... i+cache_token_value_length] by 1
            puts pos if !arr[pos]?
            key_arr.push arr[pos]
          key = key_arr.join('.')
          token_value_map[key] ?= []
          token_value_map[key].push i
      )()
      # find first in list
      find_first_position = 0
      find_first_offset = 0
      find_first = ()=>
        arr = list
        find_first_offset = 0
        # puts "find_first_position=#{find_first_position}"
        # puts "from=#{find_first_position}"
        # puts "to  =#{arr.length-cache_token_value_length}"
        for i in [find_first_position .. arr.length-cache_token_value_length] by 1 # COPYPASTE
          # puts "i=#{i}"
          key_arr = []
          for pos in [i ... i+cache_token_value_length] by 1
            key_arr.push arr[pos][0].value
          key = key_arr.join('.')
          # puts "search key=#{key}"
          # puts "search tvm=#{token_value_map[key]}"
          break if cache_position_array = token_value_map[key]
          find_first_offset++
        # puts "find_first_offset  =#{find_first_offset}"
        # puts "cache_position_array =#{JSON.stringify cache_position_array}"
        # puts "key          =#{key}"
        # puts "token_value_map[key] =#{token_value_map[key]}"
        return cache_position_array
      # make group longer than 3
      longer = (list_position, cache_position_array)=>
        # puts "longer(#{list_position}, #{cache_position_array})"
        res = [-1,-1]
        for orig_cache_position in cache_position_array
          cache_position = orig_cache_position
          count = 0
          FAtoken_list = @gram_hash.token_list
          loop
            break if !list[list_position]? # end of token list
            p_list = list[list_position++]
            c_list = FAtoken_list[cache_position++]
            # puts "'#{p_list[0].value}' != '#{c_list[0]}'"
            # break if p_list[0].value != c_list[0]
            if p_list[0].value != c_list[0]
              # puts "break p_list[0].value != c_list[0]"
              break 
            count++
          res = [count, orig_cache_position] if res[0] < count
        # puts "longer count        =#{res[0]}"
        # puts "longer orig_cache_position=#{res[1]}" # TRUE
        res
      get_list_hint = (count)->
        (list[i][0].value for i in [last_position ... last_position+count]).join(",")
          
      last_position = 0
      fill_list  = (count)->
        # puts "fill_list #{last_position}..#{last_position+count} #{get_list_hint(count)}"
        # nothing to do (see gram rule)
        last_position += count
        
      fill_cache = (count, cache_position)=>  
        # puts "fill_cache #{last_position}..#{last_position+count} #{get_list_hint(count)}"
        # adjust a,b positions and insert @ list_position
        offset = last_position-cache_position
        c2r = (t)-> # cache2real
          t+offset
        # r2c = (t)-> # real2cache
        #   t-offset
        re_merge_history = {}
        for merge_token,merge_token_position in @gram_hash.merge_history
          # select only in range
          # TODO check edge cases
          continue if !(merge_token.a >= cache_position and merge_token.b <= cache_position+count)
          value_array = []
          for v in merge_token.value_array
            if typeof v == 'number'
              v = re_merge_history[v]
              if !v?
                throw new Error("cache fail: bad merge_history position")
            else if reg_ret = /^ab(\d+)_(\d+)\[(\d+)\]$/.exec v # text "ab#{ab_k}[#{k}]"
              [skip, a, b, k] = reg_ret
              a = c2r parseInt a
              b = c2r parseInt b
              if !gram.token_a_b_list["#{a}_#{b}"]?
                throw new Error("cache fail: bad gram.token_a_b_list[#{a}_#{b}] position")
              v = gram.token_a_b_list["#{a}_#{b}"][k]
              if !v?
                puts gram.token_a_b_list["#{a}_#{b}"]
                throw new Error("cache fail: bad gram.token_a_b_list[#{a}_#{b}][#{k}] position")
            value_array.push v
          throw new Error("cache fail: check_and_mix arg count != 2 != 1") if value_array.length != 2 and value_array.length != 1
          rule = gram.rule_by_length_list[merge_token.rule.len][merge_token.rule.uid]
          # COPYPASTE check_and_mix
          ret = rule.check_and_mix value_array #, {no_strict_check:true}
          if ret?
            if re_merge_history[merge_token_position]?
              throw new Error("cache fail: re_merge_history rewrite")
            re_merge_history[merge_token_position] = ret
            
            ret.a = c2r merge_token.a
            ret.b = c2r merge_token.b
            
            # puts "#{ret.a}_#{ret.b}", ret.mx_hash.hash_key, ret.value
            
            gram.merge_history.push ret
            gram.merge_register ret, {no_new:true}
            gram.stat_merge_pair++
            gram.stat_merge_pair_mix++
            gram.stat_merge_pair_mix_hit++
          else
            puts value_array
            throw new Error("cache fail: check_and_mix returns null")
        # clear new in cache positions
        for a in [last_position ... last_position+count]
          gram.token_a_list_new[a] = []
          gram.token_b_list_new[a+1] = []
          for b in [a+1 .. last_position+count] by 1
            gram.token_a_b_list_new["#{a}_#{b}"] = []
        last_position += count
      
      while cache_position_array = find_first()
        # puts "find_first_offset=#{find_first_offset}"
        fill_list find_first_offset if find_first_offset > 0
        find_first_position += find_first_offset
        # puts "longer_find_first_position=#{find_first_position}"
        [ins_count, cache_position] = longer(find_first_position, cache_position_array)
        if ins_count
          fill_cache ins_count, cache_position
        else
          fill_list 1
        # puts "last_position=#{last_position}"
        find_first_position = last_position
        # puts "find_first_position=#{find_first_position}"
      fill_list list.length - find_first_position if list.length - find_first_position > 0
      # puts gram.token_a_b_list_new
      # gram.stat()
      return
  # ###################################################################################################
  #  real interface
  # ###################################################################################################
  toFile    : ()->
    @gram_pack()
    blob = {}
    for v in @export_list
      blob[v] = @[v]
    fs.writeFileSync @file, JSON.stringify blob
  fromFile  : ()->
    blob = JSON.parse (fs.readFileSync @file).toString()
    for v in @export_list
      @[v] = blob[v]
    return
  bind_opt : (opt={})->
    opt.cache_serialize   = @get_cache_serialize()
    opt.cache_deserialize = @get_cache_deserialize()
    opt
