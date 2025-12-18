local M = {}
---@diagnostic disable-next-line: undefined-global
local iap = iap

if not iap then
	return
end

---@type fun(payment_item_id: string?) | nil
local iap_callback = nil
---@type fun(catalog: payment_item[]) | nil
local list_callback = nil

local non_consumable_products_id_list = {}
local is_inited = false

local function iap_listener(self, transaction, error)
	if iap_callback == nil then
		error("iap_callback is nil")
		return
	end
	if error == nil then
		-- purchase is successful
		if (transaction.state == iap.TRANS_STATE_PURCHASED) then
			local iap_provider_id = iap.get_provider_id()
			if iap_provider_id == iap.PROVIDER_ID_GOOGLE and non_consumable_products_id_list[transaction.ident] then
				iap.acknowledge(transaction)
			else
				iap.finish(transaction)
			end
			iap_callback(transaction.ident)
			return
		elseif (transaction.state == iap.TRANS_STATE_RESTORED) then
			iap_callback(transaction.ident)
			return
		end
	else
		print(error.error, error.reason)
	end
	iap_callback(nil)
end

local function product_list(self, products, error)
	if list_callback == nil then
		return
	end
	if error == nil then
		products = products or {}
		for _, product in ipairs(products) do
			product.price_string = string.gsub(product.price_string, string.char(194, 160), " ")
		end
		list_callback(products)
	else
		list_callback({})
	end
	list_callback = nil
end

function M.init_sdk()
	if not iap then
		return
	end
	iap.set_listener(iap_listener)
	is_inited = true
end

function M.is_sdk_inited()
	return is_inited
end

---@type payments
local payments = {
	is_supported = function()
		return true
	end,
	set_callback = function(callback)
		iap_callback = callback
	end,
	purchase = function(id)
		non_consumable_products_id_list[id] = true
		iap.buy(id)
	end,
	get_catalog = function(purchases_id_list, callback)
		list_callback = callback
		iap.list(purchases_id_list, product_list)
	end,
	restore = function()
		iap.restore()
	end,
	consume = function(id)
		non_consumable_products_id_list[id] = nil
		iap.buy(id)
	end,
	get_purchases = nil,
}

M.payments = payments

return M
