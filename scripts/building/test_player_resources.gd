extends Node3D

## Simple test player resource management for building system testing

var inventory: Dictionary = {}

func has_resources(cost: Dictionary) -> bool:
	for resource in cost:
		var required = cost[resource]
		var available = inventory.get(resource, 0)
		if available < required:
			return false
	return true

func consume_resources(cost: Dictionary) -> bool:
	if not has_resources(cost):
		return false

	for resource in cost:
		inventory[resource] -= cost[resource]

	return true
