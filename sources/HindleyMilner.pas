unit HindleyMilner;
{$mode objfpc}{$H+}

interface

uses
   AST, 
   HMTypes, // for metatypes
   HMDataStructures, // for data structures used for type inference
   SysUtils; // for exceptions

type
   
   THMTypeSystem = class
   private
      function GetType(name: String; env: TTypeEnvironment; nongen: TTypeVariableList): TType;
      procedure Unify(t1, t2: TType);
      function Fresh(t: TType; nongen: TTypeVariableList): TType;
      function Prune(t: TType): TType;
      function IsGeneric(v: TTypeVariable; nongen: TTypeVariableList): Boolean;
      function OccursIn(v: TTypeVariable; types: TTypeList): Boolean;
      function OccursInType(v: TTypeVariable; t: TType): Boolean;
   protected
      VarGen: TVariableGenerator;
      procedure PrintEnvironment(env: TTypeEnvironment);
   public
      Int: TParameterizedType;
      Bool: TParameterizedType;
      UnitType: TParameterizedType; { cannot name this one Unit }
      constructor Create;
      function Analyse(ast: TExpression; env: TTypeEnvironment): TType;
      function Analyse(ast: TExpression; env: TTypeEnvironment; nongen: TTypeVariableList): TType;
      procedure ResetGeneratorNames;
   end;
   
implementation

constructor THMTypeSystem.Create;
begin
   Self.VarGen := TVariableGenerator.Create;
   Self.Int := CreateType('Int');
   Self.Bool := CreateType('Bool');
   Self.UnitType := CreateType('Unit');
end;

function THMTypeSystem.Analyse(ast: TExpression; env: TTypeEnvironment): TType;
begin
   Result := Self.Analyse(ast, env, VarListNew);
end;

function THMTypeSystem.Analyse(ast: TExpression; env: TTypeEnvironment; nongen: TTypeVariableList): TType;
var
   id: TIdentifier;
   ifc: TIfThenElse;
   apply: TApply;
   lambda: TLambda;
   let: TLet;
   letrec: TLetRec;
   funType, argType, resultType, defnType, condType, thenType, elseType: TType;
   newTypeVar: TTypeVariable;
   newEnv : TTypeEnvironment;
   newNongen: TTypeVariableList;
   argTypeVar: TTypeVariable;
begin
   if (ast is TIntegerLiteral) then
      Result := Self.Int
   else if (ast is TUnitLiteral) then
      Result := Self.UnitType
   else if (ast is TBooleanLiteral) then
      Result := Self.Bool
   else if (ast is TIdentifier) then
   begin
      id := ast as TIdentifier;
      Result := Self.GetType(id.Name, env, nongen);
   end
   else if (ast is TIfThenElse) then
   begin
      ifc := ast as TIfThenElse;
      condType := analyse(ifc.Cond, env, nongen);
      Self.Unify(Self.Bool, condType);
      thenType := analyse(ifc.Then_, env, nongen);
      elseType := analyse(ifc.Else_, env, nongen);
      Self.Unify(thenType, elseType);
      Result := thenType;
   end
   else if (ast is TApply) then
   begin
      apply := ast as TApply;
      funType := analyse(apply.Fun, env, nongen);
      argType := analyse(apply.Argument, env, nongen);
      resultType := Self.VarGen.GenerateVariable;
      Self.Unify(CreateFunType(argType, resultType), funType);
      Result := resultType;
   end
   else if (ast is TLambda) then
   begin
      lambda := ast as TLambda;
      argTypeVar := Self.VarGen.GenerateVariable;
      newEnv := EnvInsert(env, lambda.Variable, argTypeVar);
      newNongen := VarListInsert(nongen, argTypeVar);
      resultType := analyse(lambda.Body, newEnv, newNongen);
      Result := CreateFunType(argTypeVar, resultType);
   end
   else if (ast is TLet) then
   begin
      let := ast as TLet;
      defnType := analyse(let.Definition, env, nongen);
      newEnv := EnvInsert(env, let.Variable, defnType);
      Result := analyse(let.Body, newEnv, nongen);
   end
   else if (ast is TLetRec) then
   begin
      letrec := ast as TLetRec;
      newTypeVar := Self.VarGen.GenerateVariable;
      newEnv := EnvInsert(env, letrec.Variable, newTypeVar);
      newNonGen := VarListInsert(nongen, newTypeVar);
      defnType := analyse(letrec.Definition, newEnv, newNonGen);
      Self.Unify(newTypeVar, defnType);
      Result := analyse(letrec.Body, newEnv, nongen);
   end
   else
      Raise ETypeError.Create('Unknown type of AST node');
end;

function THMTypeSystem.GetType(name: String; env: TTypeEnvironment; nongen: TTypeVariableList): TType;
begin
   if EnvFind(env, name) then
      Result := Self.Fresh(EnvLookup(env, name), nongen)
   else
      raise ETypeError.Create('Undefined symbol ' + name);
end;

procedure THMTypeSystem.Unify(t1,t2: TType);
var
   pt1, pt2: TType;
   o1, o2: TParameterizedType;
   v: TTypeVariable;
   i: Integer;
begin
   pt1 := Self.Prune(t1);
   pt2 := Self.Prune(t2);
   if pt1 is TTypeVariable then
   begin
      v := pt1 as TTypeVariable;
      if (pt2 is TTypeVariable) and ((pt2 as TTypeVariable).Id = v.Id) then
         // do nothing
      else
      begin
         if Self.OccursInType(v, pt2) then
            Raise ETypeError.Create('Recursive unification');
         v.SetInstance(pt2);
      end;
   end
   else if (pt1 is TParameterizedType) and (pt2 is TTypeVariable) then
      Self.Unify(pt2, pt1)
   else if (pt1 is TParameterizedType) and (pt2 is TParameterizedType) then
   begin
      o1 := pt1 as TParameterizedType;
      o2 := pt2 as TParameterizedType;
      if (o1.Name <> o2.Name) or (Length(o1.Args) <> Length(o2.Args)) then
         raise ETypeError.Create('Type mismatch: ' + o1.ToStr + ' /= ' + o2.ToStr);
      for i := 0 to Length(o1.Args) - 1 do
         Self.Unify(o1.Args[i], o2.Args[i]);
   end;
end;

function THMTypeSystem.Fresh(t: TType; nongen: TTypeVariableList): TType;
var
   maps: TTypeVariableMap;
   
   function FreshRec(t: TType; nongen: TTypeVariableList): TType;
   var
      pruned: TType;
      tvar, newVar: TTypeVariable;
      oper: TParameterizedType;
      newArgs: array of TType;
      index, len: Integer;
   begin
      pruned := Self.Prune(t);
      if (pruned is TTypeVariable) then
      begin
         tvar := pruned as TTypeVariable;
         if Self.IsGeneric(tvar, nongen) then
         begin
            if VarMapFind(maps, tvar) then
            begin
               Result := VarMapLookup(maps, tvar);
            end
            else
            begin
               newVar := Self.VarGen.GenerateVariable;
               maps := VarMapInsert(maps, tvar, newVar);
               Result := newVar;
            end;
         end
         else
            Result := tvar;
      end
      else if (pruned is TParameterizedType) then
      begin
         oper := pruned as TParameterizedType;
         len := Length(oper.Args);
         SetLength(newArgs, len);
         for index := 0 to len - 1 do
            newArgs[index] := FreshRec(oper.Args[index], nongen);
         Result := TParameterizedType.Create(oper.Name, newArgs); 
      end
      else
         Raise Exception.Create('Cannot determine type of pruned type tree');
   end;
begin
   maps := VarMapNew;
   Result := FreshRec(t, nongen);
end;

function THMTypeSystem.Prune(t: TType): TType;
var
   tvar: TTypeVariable;
   inst: TType;
begin
   if (t is TTypeVariable) and (t as TTypeVariable).IsDefined then
   begin
      tvar := t as TTypeVariable;
      inst := Self.Prune(tvar.GetInstance);
      tvar.SetInstance(inst);
      Result := inst; 
   end
   else
      Result := t;
end;

function THMTypeSystem.IsGeneric(v: TTypeVariable; nongen: TTypeVariableList): Boolean;
begin
   Result := not Self.OccursIn(v, VarListToTypeList(nongen));
end;

function THMTypeSystem.OccursIn(v: TTypeVariable; types: TTypeList): Boolean;
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

function THMTypeSystem.OccursInType(v: TTypeVariable; t: TType): Boolean;
var
   tt: TType;
   oper: TParameterizedType;
begin
   tt := Self.Prune(t);
   if (tt is TTypeVariable) and (tt as TTypeVariable = v) then
      Result := True
   else if (tt is TParameterizedType) then
   begin
      oper := tt as TParameterizedType;
      Result := Self.OccursIn(v, oper.Args);
   end
   else
      Result := False;
end;

procedure THMTypeSystem.PrintEnvironment(env: TTypeEnvironment);
begin
   EnvPrint(env);
end;

procedure THMTypeSystem.ResetGeneratorNames;
begin
   Self.VarGen.ResetNameGenerator;
end;

initialization   
   
end.