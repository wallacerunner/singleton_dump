# using string as a data storage with named fields.
# This is slower than using a hashtable or object, but (allegedly) uses 10+ times less memory:
#
#	prop		this	hash	obj
#	size		64		898		859
#	time (cold)	15868	2164	10872
#	time (hot)	2356	410		300
#

$fields = @('name', 'property', 'age')
$data = 'stupid name;disgusting characteristic;27'


Update-TypeData -TypeName 'System.Array' -MemberType 'ScriptMethod' -MemberName 'set_return' -Force -Value {
	param($index, $value)
	$this[$index] = $value
	return $this
}

function set_field {
	param(
		[string]$data
		, [array]$fields
		, [string]$field
		, $value
	)
	$index = $fields.indexof($field)
	if ($index -eq -1) { return $data }
	($data.split(';')).set_return($index, $value) -join ';'
}

function get_field {
	param(
		[string] $data
		, [array] $fields
		, [string] $field
	)
	$index = $fields.indexof($field)
	if ($index -eq -1) { return $null }
	$data.split(';')[$index]
}