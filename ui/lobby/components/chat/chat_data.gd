extends RefCounted
class_name ChatData

## ChatData - 訊息資料模型
## 管理聊天訊息、反應、私訊的純資料層。

## ── 訊息結構 ──────────────────────────────────────────────

## 訊息格式：
## {
##   "id": String,              # 唯一 ID（時間戳 + 隨機）
##   "sender": String,          # 發送者暱稱
##   "sender_id": String,       # 發送者 product_user_id
##   "text": String,            # 訊息內容
##   "tab": String,             # "room" | "team" | "global" | "system"
##   "timestamp": float,        # Unix timestamp
##   "is_self": bool,           # 是否為本地玩家
##   "is_private": bool,        # 是否為私訊
##   "target_id": String,       # 私訊目標 product_user_id（非私訊時為空）
##   "reactions": Dictionary,   # { emoji: { "count": int, "user_ids": Array } }
## }

const REACTION_EMOJIS := ["❤️", "👍", "😂", "🔥", "👀", "💪", "🏆", "✨"]

static func create_message(sender: String, sender_id: String, text: String,
		tab: String, is_self: bool = false,
		is_private: bool = false, target_id: String = "") -> Dictionary:
	return {
		"id": _gen_id(),
		"sender": sender,
		"sender_id": sender_id,
		"text": text,
		"tab": tab,
		"timestamp": Time.get_unix_time_from_system(),
		"is_self": is_self,
		"is_private": is_private,
		"target_id": target_id,
		"reactions": {},
	}

static func create_system_message(text: String) -> Dictionary:
	return {
		"id": _gen_id(),
		"sender": "System",
		"sender_id": "",
		"text": text,
		"tab": "system",
		"timestamp": Time.get_unix_time_from_system(),
		"is_self": false,
		"is_private": false,
		"target_id": "",
		"reactions": {},
	}

## ── 反應操作 ──────────────────────────────────────────────

static func add_reaction(msg: Dictionary, emoji: String, user_id: String) -> void:
	if not msg.reactions.has(emoji):
		msg.reactions[emoji] = {"count": 0, "user_ids": []}
	var r: Dictionary = msg.reactions[emoji]
	if user_id not in r["user_ids"]:
		r["user_ids"].append(user_id)
		r["count"] = r["user_ids"].size()

static func remove_reaction(msg: Dictionary, emoji: String, user_id: String) -> void:
	if not msg.reactions.has(emoji):
		return
	var r: Dictionary = msg.reactions[emoji]
	if user_id in r["user_ids"]:
		r["user_ids"].erase(user_id)
		r["count"] = r["user_ids"].size()
		if r["count"] <= 0:
			msg.reactions.erase(emoji)

static func has_user_reacted(msg: Dictionary, emoji: String, user_id: String) -> bool:
	if not msg.reactions.has(emoji):
		return false
	return user_id in msg.reactions[emoji]["user_ids"]

## ── 訊息過濾 ──────────────────────────────────────────────

static func filter_by_tab(messages: Array, tab: String) -> Array:
	var result: Array = []
	for msg in messages:
		if msg.get("is_private", false):
			continue
		if msg["tab"] == tab:
			result.append(msg)
	return result

static func filter_private_messages(messages: Array, self_id: String) -> Array:
	var result: Array = []
	for msg in messages:
		if msg.get("is_private", false):
			if msg["sender_id"] == self_id or msg.get("target_id", "") == self_id:
				result.append(msg)
	return result

static func search_messages(messages: Array, query: String) -> Array:
	if query.strip_edges().is_empty():
		return messages
	var lower_query: String = query.to_lower()
	var result: Array = []
	for msg in messages:
		if msg["text"].to_lower().contains(lower_query):
			result.append(msg)
	return result

## ── 時間格式化 ────────────────────────────────────────────

static func format_timestamp(unix_time: float) -> String:
	var dt := Time.get_datetime_dict_from_unix_time(int(unix_time))
	return "%02d:%02d" % [dt.hour, dt.minute]

static func format_timestamp_relative(unix_time: float) -> String:
	var now := Time.get_unix_time_from_system()
	var diff: float = now - unix_time
	if diff < 60:
		return "剛才"
	elif diff < 3600:
		return "%d 分鐘前" % int(diff / 60)
	elif diff < 86400:
		return "%d 小時前" % int(diff / 3600)
	else:
		return format_timestamp(unix_time)

## ── 內部 ──────────────────────────────────────────────────

static func _gen_id() -> String:
	return "%d_%d" % [Time.get_unix_time_from_system() * 1000, randi() % 10000]
