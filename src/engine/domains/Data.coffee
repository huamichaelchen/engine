### Domain: Given values

Provides values that don't need to be solved
###

Domain   = require('../Domain')
Command  = require('../Command')
Variable = require('../commands/Variable')

class Data extends Domain
  priority: 200
  static: true
  # Data domains usually dont use worker
  url: null
  
  # When should Data domain take ownership of variable?
  check: (id, property) ->
    return @output.properties[property] ||     # CSS property
        @properties[property]? ||              # Getter
        property.indexOf('intrinsic-') == 0 || # Explicitly intrinsic
        property.indexOf('computed-') == 0 ||  # Explicitly computed
        (@properties[id._gss_id || id] &&      # Known object + property pair
          @properties[(id._gss_id || id) + '[' + property + ']'])?

  verify: (object, property) ->
    path = @getPath(object, property)
    if @values.hasOwnProperty(path)
      @set(null, path, @fetch(path))

Data::Variable = Variable.extend {},
  get: (path, engine, operation, continuation, scope) ->
    if meta = @getMeta(operation)
      continuation = meta.key
      scope ||= meta.scope && engine.identity[meta.scope] || engine.scope
    return engine.watch(null, path, operation, @delimit(continuation || ''), scope)

Data::Variable.Getter = Data::Variable.extend {
  signature: [
    object:   ['Query', 'Selector', 'String']
    property: ['String']
  ]
},
  'get': (object, property, engine, operation, continuation, scope) ->
    if engine.queries
      prefix = engine.Query::getScope(engine, object, continuation)

    if prop = engine.properties[property]
      unless prop.matcher
        return prop.call(engine, object, continuation)
    
    if !prefix && engine.data.check(engine.scope, property)
      prefix = engine.scope
      engine = engine.data

    return engine.watch(prefix, property, operation, @delimit(continuation || ''), scope)

Data::Variable.Expression = Variable.Expression.extend(
  before: (args, engine)->
    for arg in args
      if !arg? || arg != arg
        return NaN
)
Data::Variable.Expression.define(Variable.Expression.algebra)
    
Data::Meta = Command.Meta.extend {}, 
  'object': 

    execute: (result) ->
      return result

    descend: (engine, operation, continuation, scope, ascender, ascending) -> 
      if ascender?
        return [ascending]
      meta = operation[0]
      scope = meta.scope && engine.identity[meta.scope] || engine.scope
      [operation[1].command.solve(engine, operation[1], meta.key, scope, undefined, operation[0])]
    
module.exports = Data