<cfscript>
	/**
	* PUBLIC CONTROLLER REQUEST FUNCTIONS
	*/ 

	public any function sendEmail(
		string template="",
		string from="",
		string to="",
		string subject="",
		layout,
		string file="",
		boolean detectMultipart,
		boolean deliver=true,
		string writeToFile=""
	) {
		var loc = {};
		loc.deliver = Duplicate(arguments.deliver);
		loc.writeToFile = Duplicate(arguments.writeToFile);

		$args(args=arguments, name="sendEmail", combine="template/templates/!,layout/layouts,file/files", required="template,from,to,subject");

		loc.nonPassThruArgs = "writetofile,template,templates,layout,layouts,file,files,detectMultipart,deliver,tagContent";
		loc.mailTagArgs = "from,to,bcc,cc,charset,debug,failto,group,groupcasesensitive,mailerid,mailparams,maxrows,mimeattach,password,port,priority,query,replyto,server,spoolenable,startrow,subject,timeout,type,username,useSSL,useTLS,wraptext,remove";

		// if two templates but only one layout was passed in we set the same layout to be used on both
		if (ListLen(arguments.template) > 1 && ListLen(arguments.layout) == 1)
		{
			arguments.layout = ListAppend(arguments.layout, arguments.layout);
		}

		// set the variables that should be available to the email view template (i.e. the custom named arguments passed in by the developer)
		for (loc.key in arguments)
		{
			if (!ListFindNoCase(loc.nonPassThruArgs, loc.key) && !ListFindNoCase(loc.mailTagArgs, loc.key))
			{
				variables[loc.key] = arguments[loc.key];
				StructDelete(arguments, loc.key);
			}
		}

		// get the content of the email templates and store them as cfmailparts
		arguments.mailparts = [];
		loc.iEnd = ListLen(arguments.template);
		for (loc.i=1; loc.i <= loc.iEnd; loc.i++)
		{
			// include the email template and return it
			loc.item = ListGetAt(arguments.template, loc.i);
			loc.content = $renderPage($template=loc.item, $layout=ListGetAt(arguments.layout, loc.i));
			loc.mailpart = {};
			loc.mailpart.tagContent = loc.content;
			if (ArrayIsEmpty(arguments.mailparts))
			{
				ArrayAppend(arguments.mailparts, loc.mailpart);
			}
			else
			{
				// make sure the text version is the first one in the array
				loc.existingContentCount = ListLen(arguments.mailparts[1].tagContent, "<");
				loc.newContentCount = ListLen(loc.content, "<");
				if (loc.newContentCount < loc.existingContentCount)
				{
					ArrayPrepend(arguments.mailparts, loc.mailpart);
				}
				else
				{
					ArrayAppend(arguments.mailparts, loc.mailpart);
				}
				arguments.mailparts[1].type = "text";
				arguments.mailparts[2].type = "html";
			}
		}

		// return a struct containing mailpart content using type as the key
		loc.rv = {};
		loc.rv["html"] = "";
		loc.rv["text"] = "";
		// figure out if the email should be sent as html or text when only one template is used and the developer did not specify the type explicitly
		if (ArrayLen(arguments.mailparts) == 1)
		{
			arguments.tagContent = arguments.mailparts[1].tagContent;
			StructDelete(arguments, "mailparts");
			if (arguments.detectMultipart && !StructKeyExists(arguments, "type"))
			{
				if (Find("<", arguments.tagContent) && Find(">", arguments.tagContent))
				{
					arguments.type = "html";
				}
				else
				{
					arguments.type = "text";
				}
			}
			loc.rv[arguments.type] = arguments.tagContent;
		}
		else
		{
			// return a struct containing mailparts using type the the key
			loc.iEnd = ArrayLen(arguments.mailparts);
			for (loc.i=1; loc.i <= loc.iEnd; loc.i++) {
				loc.rv[arguments.mailparts[loc.i].type] = arguments.mailparts[loc.i].tagContent;
			}
		}

		// attach files using the cfmailparam tag
		if (Len(arguments.file))
		{
			arguments.mailparams = [];
			loc.iEnd = ListLen(arguments.file);
			for (loc.i=1; loc.i <= loc.iEnd; loc.i++)
			{
				loc.item = ListGetAt(arguments.file, loc.i);
				arguments.mailparams[loc.i] = {};
				if (!ReFindNoCase("\\|/", loc.item))
				{
					// no directory delimiter is present so append the path
					loc.item = ExpandPath(get("filePath")) & "/" & loc.item;
				}
				arguments.mailparams[loc.i].file = loc.item;
			}
		}

		// delete arguments that we don't want to pass through to the cfmail tag
		loc.iEnd = ListLen(loc.nonPassThruArgs);
		for (loc.i=1; loc.i <= loc.iEnd; loc.i++)
		{
			loc.item = ListGetAt(loc.nonPassThruArgs, loc.i);
			StructDelete(arguments, loc.item);
		}

		// also return the args passed to cfmail
		StructAppend(loc.rv, arguments);

		// write the email body to file
		if (Len(loc.writeToFile))
		{
			loc.output = ListAppend(loc.rv.text, loc.rv.html, "#Chr(13)##Chr(10)##Chr(13)##Chr(10)#");
			$file(action="write", file="#loc.writeToFile#", output="#loc.output#");
		}

		// send the email using the cfmail tag
		if (loc.deliver)
		{
			$mail(argumentCollection=arguments);
		}
		return loc.rv;
	}
 
	public any function sendFile(
		required string file,
		string name="",
		string type="",
		string disposition,
		string directory="",
		boolean deleteFile=false,
		boolean $testingMode=false
	) {
		var loc = {};
		$args(name="sendFile", args=arguments);

		// Check whether the resource is a ram resource or physical file
		if(!listFirst(arguments.file, "://") EQ "ram"){
			loc.relativeRoot = get("rootPath");
			if (Right(loc.relativeRoot, 1) != "/")
			{
				loc.relativeRoot &= "/";
			}
			loc.root = ExpandPath(loc.relativeRoot);
			loc.folder = arguments.directory;
			if (!Len(loc.folder))
			{
				loc.folder = loc.relativeRoot & get("filePath");
			}
			if (Left(loc.folder, Len(loc.root)) == loc.root)
			{
				loc.folder = RemoveChars(loc.folder, 1, Len(loc.root));
			}
			loc.fullPath = Replace(loc.folder, "\", "/", "all");
			loc.fullPath = ListAppend(loc.fullPath, arguments.file, "/");
			loc.fullPath = ExpandPath(loc.fullPath);
			loc.fullPath = Replace(loc.fullPath, "\", "/", "all");
			loc.file = ListLast(loc.fullPath, "/");
			loc.directory = Reverse(ListRest(Reverse(loc.fullPath), "/"));

			// if the file is not found, try searching for it
			if (!FileExists(loc.fullPath))
			{
				loc.match = $directory(action="list", directory=loc.directory, filter="#loc.file#.*");

				// only extract the extension if we find a single match
				if (loc.match.recordCount == 1)
				{
					loc.file &= "." & ListLast(loc.match.name, ".");
					loc.fullPath = loc.directory & "/" & loc.file;
				}
				else
				{
					$throw(type="Wheels.FileNotFound", message="A file could not be found.", extendedInfo="Make sure a file with the name `#loc.file#` exists in the `#loc.directory#` folder.");
				}
			}
			loc.name = loc.file;
		}
		else {
			loc.fullPath = arguments.file;
			loc.file 	 = arguments.file;
			// For ram:// resources, skip the physical file check but still check the thing exists
			if (!FileExists(loc.fullPath)){
				$throw(type="Wheels.FileNotFound", message="ram:// resource could not be found.", extendedInfo="Make sure a resource with the name `#loc.file#` exists in memory");
			}
			// Make the default display name behaviour the same as physical files
			loc.name     = replace(arguments.file, "ram://","","one");
		}

		loc.extension = ListLast(loc.file, ".");

		// replace the display name for the file if supplied
		if (Len(arguments.name))
		{
			loc.name = arguments.name;
		}

		loc.mime = arguments.type;
		if (!Len(loc.mime))
		{
			loc.mime = mimeTypes(loc.extension);
		}

		// if testing, return the variables
		if (arguments.$testingMode)
		{
			StructAppend(loc, arguments, false);
			loc.rv = loc;
		}
		else
		{
			// prompt the user to download the file
			$header(name="content-disposition", value="#arguments.disposition#; filename=""#loc.name#""");
			$content(type=loc.mime, file=loc.fullPath, deleteFile=arguments.deleteFile);
		}
		if(structKeyExists(loc,"rv")){
			return loc.rv;
		}
	}
 
	public boolean function isSecure() {
		var loc = {};
		if (request.cgi.server_port_secure == "true")
		{
			loc.rv = true;
		}
		else
		{
			loc.rv = false;
		}
		return loc.rv;
	}

	public boolean function isAjax() {
		var loc = {};
		if (request.cgi.http_x_requested_with == "XMLHTTPRequest")
		{
			loc.rv = true;
		}
		else
		{
			loc.rv = false;
		}
		return loc.rv;
	}

	public boolean function isGet() {
		var loc = {};
		if (request.cgi.request_method == "get")
		{
			loc.rv = true;
		}
		else
		{
			loc.rv = false;
		}
		return loc.rv;
	}
	public boolean function isPost() {
		var loc = {};
		if (request.cgi.request_method == "post")
		{
			loc.rv = true;
		}
		else
		{
			loc.rv = false;
		}
		return loc.rv;
	} 

	public boolean function isPut() {
		return request.cgi.request_method == "put";
	}

	public boolean function isPatch() {
		return request.cgi.request_method == "patch";
	}

	public boolean function isDelete() {
		return request.cgi.request_method == "delete";
	}

	public boolean function isHead() {
		return request.cgi.request_method == "head";
	}
		
	public boolean function isOptions() {
		return request.cgi.request_method == "options";
}

</cfscript>
