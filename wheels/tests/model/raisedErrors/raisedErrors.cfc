<cfcomponent extends="wheelsMapping.test">

	<cffunction name="test_table_not_found">
		<cfset loc.e = raised("model('table_not_found')")>
		<cfset halt(false, "loc.e")>
		<cfset loc.r = "Wheels.TableNotFound">
		<cfset assert("loc.e eq loc.r")>
	</cffunction>

</cfcomponent>