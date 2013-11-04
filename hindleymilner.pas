unit HindleyMilner;
{$mode objfpc}{$H+}

interface

uses
   AST,
   HMTypes,
   SysUtils, // for exceptions
   fgl; // for generic data structures

type
   
   // Environment for storing type variables
   TEnvironment = specialize TFPGMap<String,TType>;      
   
   TVariableList = array of TVariable;
   
   // TVariableMap = specialize TFPGMap<TVariable,TVariable>;
   // This variant of TVariableMap does not compile because it can't
   // find overloaded comparison operators for TVariables. Even if they're
   // defined in HMTypes. This is very strange, but in FreePascal you just
   // can't overload operators in classes. But specializing TFPGMap requires
   // overloaded comparison operators. So the best thing we can do is to wrap
   // a TVariable into record, for which we actually can overload comparison
   // operators.
   // This is awful and i'm deeply dissapointed about Free Pascal.
   TVariableMap = specialize TFPGMap<TWrappedVariable,TWrappedVariable>;
   
   TTypeSystem = class
   private
      NextVariableId: Integer;
      Generator: PGenerator;
      function GetType(name: String; env: TEnvironment; nongen: TVariableList): TType;
      procedure Unify(t1, t2: TType);
      function Fresh(t: TType; nongen: TVariableList): TType;
      function Fresh(t: TType; nongen: TVariableList; maps: TVariableMap): TType;
      function Prune(t: TType): TType;
      function IsGeneric(v: TVariable; nongen: TVariableList): Boolean;
      function OccursIn(v: TVariable; types: array of TType): Boolean;
      function OccursInType(v: TVariable; t: TType): Boolean;
   public
      Int: TOper;
      Bool: TOper;
      constructor Create;
      function GenerateVariable: TVariable;
      function Analyse(ast: TSyntaxNode; env: TEnvironment): TType;
      function Analyse(ast: TSyntaxNode; env: TEnvironment; nongen: TVariableList): TType;
   end;
   
   function IsIntegerLiteral(s: String): Boolean;
   
implementation

constructor TTypeSystem.Create;
var
   gen: TGenerator;
begin
   gen := TGenerator.Create;
   Self.NextVariableId := 0;
   Self.Generator := Pointer(gen);
   Self.Int := TOper.Create('int', []);
   Self.Bool := TOper.Create('bool', []);
end;

function TTypeSystem.Analyse(ast: TSyntaxNode; env: TEnvironment): TType;
var
   nongen: TVariableList;
begin
   SetLength(nongen, 0);
   Result := Self.Analyse(ast, env, nongen);
end;

function TTypeSystem.Analyse(ast: TSyntaxNode; env: TEnvironment; nongen: TVariableList): TType;
var
   id: TIdent;
   apply: TApply;
   lambda: TLambda;
   let: TLet;
   letrec: TLetRec;
   funType, argType, resultType, defnType: TType;
   newTypeVar: TVariable;
   newEnv : TEnvironment;
   newNongen: TVariableList;
   i, len: Integer;
begin
   if (ast is TIdent) then
   begin
      id := ast as TIdent;
      Result := Self.GetType(id.Name, env, nongen);
   end
   else if (ast is TApply) then
   begin
      apply := ast as TApply;
      funType := analyse(apply.Fun, env, nongen);
      argType := analyse(apply.Argument, env, nongen);
      resultType := Self.GenerateVariable;
      Self.Unify(CreateFunType(argType, resultType), funType);
      Result := resultType;
   end
   else if (ast is TLambda) then
   begin
      lambda := ast as TLambda;
      argType := Self.GenerateVariable;
      // copying environment
      newEnv := TEnvironment.Create;
      for i := 0 to env.Count - 1 do
         newEnv.Add(env.GetKey(i), env.GetData(i));
      newEnv.Add(lambda.Variable, argType);
      resultType := analyse(lambda.Body, newEnv, nongen);
      Result := CreateFunType(argType, resultType);
   end
   else if (ast is TLet) then
   begin
      let := ast as TLet;
      defnType := analyse(let.Definition, env, nongen);
      // copying environment
      newEnv := TEnvironment.Create;
      for i := 0 to env.Count - 1 do
         newEnv.Add(env.GetKey(i), env.GetData(i));
      // inserting new type variable from let into environemnt
      newEnv.Add(let.Variable, defnType);
      Result := analyse(let.Body, newEnv, nongen);
   end
   else if (ast is TLetRec) then
   begin
      letrec := ast as TLetRec;
      newTypeVar := Self.GenerateVariable;
      // copying environment
      newEnv := TEnvironment.Create;
      for i := 0 to env.Count - 1 do
         newEnv.Add(env.GetKey(i), env.GetData(i));
      // inserting new type variable from letrec into environemnt
      newEnv.Add(letrec.Variable, newTypeVar);
      // copying nongeneric variables list
      len := Length(nongen);
      SetLength(newNongen, len + 1);
      for i := 0 to len - 1 do
         newNongen[i] := nongen[i];
      // inserting new non-generic variable into nongen
      newNongen[len] := newTypeVar;
      defnType := analyse(letrec.Definition, newEnv, newNonGen);
      Self.Unify(newTypeVar, defnType);
      Result := analyse(letrec.Body, newEnv, nongen);
   end
   else
      Raise Exception.Create('Analysis error: Unknown type of AST node');
end;

function TTypeSystem.GenerateVariable: TVariable;
begin
   Result := TVariable.Create(Self.NextVariableId, @(Self.Generator));
   NextVariableId := NextVariableId + 1;
end;

function TTypeSystem.GetType(name: String; env: TEnvironment; nongen: TVariableList): TType;
var index: Integer;
begin
   if env.Find(name, index) then
      Result := Self.Fresh(env.Data[index], nongen)
   else if IsIntegerLiteral(name) then
      Result := Self.Int
   else
      raise EParseError.Create('Undefined symbol ' + name);
end;

procedure TTypeSystem.Unify(t1,t2: TType);
var
   pt1, pt2: TType;
begin
   // TODO: write this down
   //    val type1 = prune(t1)
   //    val type2 = prune(t2)
   //   (type1, type2) match {
   //   case (a: Variable, b) => if (a != b) {
   // 	if (occursintype(a, b))
   // 	  throw new TypeError("recursive unification")
   // 	a.instance = Some(b)
   //   }
   //   case (a: Oper, b: Variable) => unify(b, a)
   //   case (a: Oper, b: Oper) => {
   // 	if (a.name != b.name ||
   // 	  a.args.length != b.args.length) throw new TypeError("Type mismatch: "+string(a)+"≠"+string(b))   
   // 	for(i <- 0 until a.args.length)
   // 	  unify(a.args(i), b.args(i))
   //   }
   // }
   pt1 := Self.Prune(t1);
   pt2 := Self.Prune(t2);
end;

function TTypeSystem.Fresh(t: TType; nongen: TVariableList): TType;
var mappings: TVariableMap;
begin
   mappings := TVariableMap.Create;
   Result := Self.Fresh(t, nongen, mappings);
end;

function TTypeSystem.Fresh(t: TType; nongen: TVariableList; maps: TVariableMap): TType;
var
   pruned: TType;
   tvar, newVar: TVariable;
   oper: TOper;
   newArgs: array of TType;
   index, len: Integer;
begin
   pruned := Self.Prune(t);
   if (pruned is TVariable) then
   begin
      tvar := pruned as TVariable;
      if Self.IsGeneric(tvar, nongen) then
      begin
         if maps.Find(WrapVariable(tvar), index) then
            Result := tvar
         else
         begin
            newVar := Self.GenerateVariable;
            Result := newVar;
         end;
      end
      else
         Result := tvar;
   end
   else if (pruned is TOper) then
   begin
      oper := pruned as TOper;
      len := Length(oper.Args);
      SetLength(newArgs, len);
      for index := 0 to len - 1 do
         newArgs[index] := Self.Fresh(oper.Args[index], nongen, maps);
      Result := TOper.Create(oper.Name, newArgs); 
   end
   else
      Raise Exception.Create('Cannot determine type of pruned type tree');
end;

function TTypeSystem.Prune(t: TType): TType;
var
   tvar: TVariable;
   inst: TType;
begin
   if (t is TVariable) and (t as TVariable).IsDefined then
   begin
      tvar := t as TVariable;
      inst := Self.Prune(tvar.GetInstance);
      tvar.SetInstance(inst);
      Result := inst; 
   end
   else
      Result := t;
end;

function TTypeSystem.IsGeneric(v: TVariable; nongen: TVariableList): Boolean;
var
   types: array of TType;
   i, len: Integer;
begin
   len := Length(nongen);
   SetLength(types, len);
   for i := 0 to len - 1 do
      types[i] := nongen[i];
   Result := not Self.OccursIn(v, types);
end;

function TTypeSystem.OccursIn(v: TVariable; types: array of TType): Boolean;
var
   i: Integer;
begin
   for i := 0 to Length(types) - 1 do
      if Self.OccursInType(v, types[i]) then
      begin
         Result := True;
         Exit;
      end;
   Result := False;
end;

function TTypeSystem.OccursInType(v: TVariable; t: TType): Boolean;
var
   tt: TType;
   oper: TOper;
begin
   tt := Self.Prune(t);
   if (tt is TVariable) and (tt as TVariable = v) then
      Result := True
   else if (tt is TOper) then
   begin
      oper := tt as TOper;
      Result := Self.OccursIn(v, oper.Args);
   end
   else
      Result := False;
end;

function IsIntegerLiteral(s: String): Boolean;
const
   digits: Set of Char = ['0'..'9'];
var
   i: Integer;
begin
   // Hello, mr. Nazarov. Here we meet again.
   for i := 1 to Length(s) do
      if not(s[i] in digits) then
      begin
         Result := False;
         Exit;
      end;
   Result := True;
end;

initialization   
   
end.
