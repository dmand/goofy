unit HMDataStructures;
{$mode objfpc}{$H+}
interface

uses HMTypes, SysUtils;

type
  
   // Environment for mapping types to it's names
   TTypeEnvironmentEntry = record
      Key: String;
      Value: TType;
   end;  
   TTypeEnvironment = array of TTypeEnvironmentEntry;
   
   // Variable and type-list for storing non-generic variables
   TTypeVariableList = array of TTypeVariable;
   TTypeList = array of TType;
   
   // Used for creating fresh type
   TVarMapEntry = record
      Key: TTypeVariable;
      Value: TTypeVariable;
   end;
   TTypeVariableMap = array of TVarMapEntry;
   
function EnvNew: TTypeEnvironment;
function EnvInsert(env: TTypeEnvironment; key: String; value: TType): TTypeEnvironment;
function EnvFind(env: TTypeEnvironment; key: String): Boolean;
function EnvLookup(env: TTypeEnvironment; key: String): TType;
function EnvDelete(env: TTypeEnvironment; key: String): TTypeEnvironment;
function EnvUpdate(env: TTypeEnvironment; key: String; value: TType): TTypeEnvironment;
function EnvCopy(env: TTypeEnvironment): TTypeEnvironment;
procedure EnvPrint(env: TTypeEnvironment);

function VarListNew: TTypeVariableList;
function VarListInsert(list: TTypeVariableList; v: TTypeVariable): TTypeVariableList;
function VarListDelete(list: TTypeVariableList; v: TTypeVariable): TTypeVariableList;
function VarListFind(list: TTypeVariableList; v: TTypeVariable): Boolean;
function VarListToTypeList(list: TTypeVariableList): TTypeList;
procedure VarListPrint(list: TTypeVariableList);

function VarMapNew: TTypeVariableMap;
function VarMapInsert(map: TTypeVariableMap; key: TTypeVariable; value: TTypeVariable): TTypeVariableMap;
function VarMapFind(map: TTypeVariableMap; key: TTypeVariable): Boolean;
function VarMapLookup(map: TTypeVariableMap; key: TTypeVariable): TTypeVariable;
function VarMapDelete(map: TTypeVariableMap; key: TTypeVariable): TTypeVariableMap;
procedure VarMapPrint(map: TTypeVariableMap);

implementation

function EnvNew: TTypeEnvironment;
begin
   Result := Nil;
end;

function EnvInsert(env: TTypeEnvironment; key: String; value: TType): TTypeEnvironment;
var
   newEnv: TTypeEnvironment;
   i, len: Integer;
begin
   len := Length(env);
   if (len <> 0) then
   begin
      if EnvFind(env, key) then
         newEnv := EnvUpdate(env, key, value)
      else
      begin
         SetLength(newEnv, len + 1);
         for i := 0 to len - 1 do
            newEnv[i] := env[i];
         newEnv[len].Key := key;
         newEnv[len].Value := value;
      end
   end
   else
   begin
      SetLength(newEnv, 1);
      newEnv[0].Key := key;
      newEnv[0].Value := value;
   end;
   Result := newEnv;
 end;

function EnvFind(env: TTypeEnvironment; key: String): Boolean;
var
   i: Integer;
begin
   for i := 0 to High(env) do
      if env[i].Key = key then
      begin
         Result := True;
         Exit;
      end;
   Result := False;
end;

function EnvLookup(env: TTypeEnvironment; key: String): TType;
var
   i: Integer;
begin
   for i := 0 to High(env) do
      if env[i].Key = key then
      begin
         Result := env[i].Value;
         Exit;
      end;
   raise Exception.Create('Type environment has no such key: ' + key + '. Use EnvFind before EnvLookup.');
end;

function EnvDelete(env: TTypeEnvironment; key: String): TTypeEnvironment;
var
   newEnv: TTypeEnvironment;
   i, index: Integer;
begin
   SetLength(newEnv, Length(env) - 1);
   index := 0;
   for i := 0 to High(Env) do
      if env[i].Key <> key then
      begin
         newEnv[index] := env[i];
         index := index + 1;
      end;
   Result := newEnv;
end;

function EnvUpdate(env: TTypeEnvironment; key: String; value: TType): TTypeEnvironment;
var
   newEnv: TTypeEnvironment;
   i: Integer;
begin
   SetLength(newEnv, Length(env));
   for i := 0 to High(Env) do
   begin
      newEnv[i] := env[i];
      if env[i].Key = key then
         newEnv[i].Value := value;
   end;
   Result := newEnv;
end;

function EnvCopy(env: TTypeEnvironment): TTypeEnvironment;
var
   newEnv: TTypeEnvironment;
   i: Integer;
begin
   SetLength(newEnv, Length(env));
   for i := 0 to High(Env) do
      newEnv[i] := env[i];
   Result := newEnv;
end;

procedure EnvPrint(env: TTypeEnvironment);
var
   i: Integer;
begin
   writeln('Environment:');
   if Length(env) = 0 then
      writeln('Empty environment')
   else
      for i := 0 to Length(env) - 1 do
         writeln(env[i].Key, ' -> ', env[i].Value.ToStr);
end;

function VarListNew: TTypeVariableList;
begin
   Result := Nil;
end;

function VarListInsert(list: TTypeVariableList; v: TTypeVariable): TTypeVariableList;
var
   len: Integer;
begin
   len := Length(list);
   SetLength(list, len + 1);
   list[len] := v;
   Result := list;
end;

function VarListDelete(list: TTypeVariableList; v: TTypeVariable): TTypeVariableList;
var
   i, index, len: Integer;
   newList: TTypeVariableList;
begin
   len := Length(list);
   SetLength(newList, len - 1);
   index := 0;
   for i := 0 to len - 1 do
      if list[i].Id <> v.Id then
      begin
         newList[index] := list[i];
         index := index + 1;
      end;
   Result := newList;
end;

procedure VarListPrint(list: TTypeVariableList);
var
   i: Integer;
begin
   writeln('Variable list:');
   if Length(list) = 0 then
      writeln('List is empty')
   else
      for i := 0 to High(list) do
         writeln(list[i].ToStr);
end;

function VarListFind(list: TTypeVariableList; v: TTypeVariable): Boolean;
var
   i: Integer;
begin
   for i := 0 to High(list) do
      if list[i].Id = v.Id then
      begin
         Result := True;
         Exit;
      end;
   Result := False;
end;

function VarListToTypeList(list: TTypeVariableList): TTypeList;
var
   types: TTypeList;
   i: Integer;
begin
   SetLength(types, Length(list));
   for i := 0 to High(list) do
      types[i] := list[i];
   Result := types;
end;

function VarMapNew: TTypeVariableMap;
begin
   Result := nil;
end;

function VarMapInsert(map: TTypeVariableMap; key: TTypeVariable; value: TTypeVariable): TTypeVariableMap;
var
   newMap: TTypeVariableMap;
   i, len: Integer;
begin
   len := Length(map);
   if (len <> 0) then
   begin
      if VarMapFind(map, key) then
         raise Exception.Create('Cannot insert an existing key:' + key.ToStr);
      SetLength(newMap, len + 1);
      for i := 0 to len - 1 do
         newMap[i] := Map[i];
      newMap[len].Key := key;
      newMap[len].Value := value;
   end
   else
   begin
      SetLength(newMap, 1);
      newMap[0].Key := key;
      newMap[0].Value := value;
   end;
   Result := newMap;
end;

function VarMapFind(map: TTypeVariableMap; key: TTypeVariable): Boolean;
var
   i: Integer;
begin
   for i := 0 to High(map) do
      if map[i].Key.Id = key.Id then
      begin
         Result := True;
         Exit;
      end;
   Result := False;
end;

function VarMapLookup(map: TTypeVariableMap; key: TTypeVariable): TTypeVariable;
var
   i: Integer;
begin
   for i := 0 to High(map) do
      if map[i].Key.Id = key.Id then
      begin
         Result := map[i].Value;
         Exit;
      end;
   raise Exception.Create('VariableMap has no such key: ' + key.ToStr + '. Use EnvFind before EnvLookup.');
end;

function VarMapDelete(map: TTypeVariableMap; key: TTypeVariable): TTypeVariableMap;
var
   newMap: TTypeVariableMap;
   i, index: Integer;
begin
   SetLength(newMap, Length(map) - 1);
   index := 0;
   for i := 0 to High(map) do
      if map[i].Key.Id <> key.Id then
      begin
         newMap[index] := map[i];
         index := index + 1;
      end;
   Result := newMap;
end;

procedure VarMapPrint(map: TTypeVariableMap);
var
   i: Integer;
begin
   writeln('Variable map:');
   if Length(map) = 0 then
      writeln('Empty environment')
   else
      for i := 0 to High(map) do
         writeln(map[i].Key.ToStr, ' -> ', map[i].Value.ToStr);
end;

initialization

end.
