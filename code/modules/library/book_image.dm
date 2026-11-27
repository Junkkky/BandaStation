/// Kept separate from the edit transaction: a download may finish after the reader has closed the book.
/obj/item/book/proc/import_illustration(url, mob/living/user)
	return download_book_illustration(url, REF(user))

/// A source checkout on Windows can reuse the portable Python installed by the project's bootstrap.
/proc/book_image_python()
	if(world.system_type != MS_WINDOWS)
		return "python3"
	var/static/executable
	if(!executable)
		executable = "python.exe"
		var/static/regex/bootstrap_dir = regex(@"^python-[0-9]+\.[0-9]+\.[0-9]+/$")
		for(var/dir in flist("tools/bootstrap/.cache/"))
			if(!bootstrap_dir.Find(dir) || bootstrap_dir.match != dir)
				continue
			var/path = "tools/bootstrap/.cache/[dir]"
			if(fexists("[path]python.exe") && fexists("[path]Lib/site-packages/PIL/Image.py"))
				executable = replacetext("[path]python.exe", "/", "\\")
				break
	return executable

/// The global process owns the worker slot and temporary files even if the book is deleted during shell().
/proc/download_book_illustration(url, reader_ref)
	if(!is_valid_portrait_image_url(url))
		return list("error" = "Нужна прямая HTTPS-ссылка на PNG или JPEG с хостинга для портретов.")
	if(!shell())
		return list("error" = "Импорт по ссылке недоступен в текущем режиме запуска сервера. Сообщите администратору.")
	var/static/list/active_readers = list()
	if(active_readers[reader_ref])
		return list("error" = "Предыдущая иллюстрация ещё загружается.")
	if(length(active_readers) >= 3)
		return list("error" = "Сейчас загружаются другие иллюстрации. Попробуйте ещё раз через несколько секунд.")
	var/job = "tmp/book-illustration-[rustg_generate_uuid_v4()]"
	var/worker_path = "[job].py"
	var/source_path = "[job].url"
	var/image_path = "[job].txt"
	// Extract the worker from the compiled resources. Runtime deployments may omit source files.
	if(!fcopy('code/modules/library/book_image.py', worker_path) || !text2file(url, source_path))
		fdel(worker_path)
		fdel(source_path)
		return list("error" = "Сервер не смог подготовить загрузку иллюстрации.")

	active_readers[reader_ref] = TRUE
	var/python = book_image_python()
	// shell() yields. Every argument comes from the server; the URL stays in the request file.
	var/result = shell("[python] -I -B [worker_path] [MAX_LIBRARY_IMAGE_LENGTH] [job]")
	active_readers -= reader_ref
	fdel(worker_path)
	var/png
	if(!isnull(result) && result == 0 && fexists(image_path))
		png = file2text(image_path)
	fdel(source_path)
	if(fexists(image_path))
		fdel(image_path)
	if(istext(png) && length(png) <= MAX_LIBRARY_IMAGE_LENGTH && findtextEx(png, "iVBORw0KGgo") == 1)
		return list("image" = png)
	// An encoded Unix wait status stores a normal exit code in its high byte.
	if(world.system_type == UNIX && result >= 256 && !(result & 255))
		result >>= 8
	switch(result)
		if(2)
			return list("error" = "Не удалось получить картинку. Проверьте, что ссылка ведёт прямо на открытое изображение.")
		if(3)
			return list("error" = "Нужен PNG или JPEG размером до 8 МиБ и до 16 мегапикселей.")
		if(4)
			return list("error" = "Хостинг слишком долго не отвечает. Попробуйте ещё раз.")
		if(5)
			return list("error" = "Обработчику иллюстраций недоступна библиотека Pillow. Сообщите администратору.")
		if(null, 127, 9009)
			return list("error" = "Сервер не смог запустить Python для обработки изображения. Сообщите администратору.")
	log_world("Book illustration worker returned no usable image (exit status: [result]).")
	return list("error" = "Сервер не смог обработать иллюстрацию.")
