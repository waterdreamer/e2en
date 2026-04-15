--client proxy type for ExampleService
--this should match whatever you put in the Service's Client table
--client methods omit the player param (injected by framework)

local root = script.Parent.Parent.Parent.Parent
local Types = require(root.Types)

export type ExampleServiceProxy = {
	CoinsChanged: Types.ClientRemoteSignal<number, number>,
	Coins: Types.ClientRemoteProperty<number>,
	GetCoins: (self: ExampleServiceProxy) -> number,
	AddCoins: (self: ExampleServiceProxy, amount: number) -> boolean,
}

return nil
