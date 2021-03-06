package tink.core;

abstract Callback<T>(T->Void) from (T->Void) {
  
  inline function new(f) 
    this = f;
  
  @:to inline function toFunction()
    return this;
    
  public inline function invoke(data:T):Void //TODO: consider swallowing null here
    (this)(data);
    
  @:to static function ignore<T>(cb:Callback<Noise>):Callback<T>
    return function () cb.invoke(Noise);
    
  @:from static function fromNiladic<A>(f:Void->Void):Callback<A> //inlining this seems to cause recursive implicit casts
    return new Callback(function (r) f());
  
  @:from static function fromMany<A>(callbacks:Array<Callback<A>>):Callback<A> 
    return
      function (v:A) 
        for (callback in callbacks)
          callback.invoke(v);
          
  @:noUsing static public function defer(f:Void->Void) {    
    #if macro
      f();
    #elseif tink_runloop
      tink.RunLoop.current.work(f);
    #elseif nodejs
      js.Node.process.nextTick(f);
    #elseif ((haxe_ver >= 3.3) || js || flash || openfl)
      haxe.Timer.delay(f, 0);
    #else
      f();
    #end
  }
}

abstract CallbackLink(Void->Void) to Void->Void {
  
  inline function new(link:Void->Void) 
    this = link;
    
  public inline function dissolve():Void 
    if (this != null) (this)();
    
  @:to inline function toCallback<A>():Callback<A> 
    return this;
    
  @:from static inline function fromFunction(f:Void->Void) 
    return new CallbackLink(f);
    
  @:from static function fromMany(callbacks:Array<CallbackLink>)
    return fromFunction(function () for (cb in callbacks) cb.dissolve());
}

abstract CallbackList<T>(Array<Ref<Callback<T>>>) {
  
  public var length(get, never):Int;
  
  inline public function new():Void
    this = [];
  
  inline function get_length():Int 
    return this.length;  
  
  public function add(cb:Callback<T>):CallbackLink {
    var cell = Ref.to(cb);
    
    this.push(cell);
        
    return function () {
      if (this.remove(cell))
        cell.value = null;
      cell = null;
    }
  }
    
  public function invoke(data:T) 
    for (cell in this.copy()) 
      if (cell.value != null) //This occurs when an earlier cell in this run dissolves the link for a later cell
        cell.value.invoke(data);
      
  public function clear():Void 
    for (cell in this.splice(0, this.length)) 
      cell.value = null;
}