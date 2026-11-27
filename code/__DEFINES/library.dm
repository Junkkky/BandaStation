#define DEFAULT_UPLOAD_CATAGORY "Fiction"
#define DEFAULT_SEARCH_CATAGORY "Any"

///How many books should we load per page?
#define BOOKS_PER_PAGE 18
///How many checkout records should we load per page?
#define CHECKOUTS_PER_PAGE 17
///How many inventory items should we load per page?
#define INVENTORY_PER_PAGE 19

/// Manuscript limits apply before the edition is sent to other clients or the SQL archive.
#define MAX_LIBRARY_BOOK_PAGES 16
#define MAX_LIBRARY_PAGE_LENGTH 1000
#define MAX_LIBRARY_CAPTION_LENGTH 120
/// Encoded titles and author bylines are stored in VARCHAR(45) archive columns.
#define MAX_LIBRARY_METADATA_LENGTH 45
#define MAX_LIBRARY_IMAGE_LENGTH (128 * 1024)
#define MAX_LIBRARY_BOOK_IMAGES_LENGTH (512 * 1024)
/// The archived plain-text projection must fit the existing MariaDB TEXT column in bytes.
#define MAX_LIBRARY_ARCHIVE_TEXT_BYTES 65535

// Book categories, used in SQL so don't change randomly
#define BOOK_CATEGORY_FICTION "Fiction"
#define BOOK_CATEGORY_NONFICTION "Non-fiction"
#define BOOK_CATEGORY_RELIGION "Religion"
#define BOOK_CATEGORY_ADULT "Adult"
#define BOOK_CATEGORY_REFERENCE "Reference"
/// If making a book of this category it will be randomly selected from all categories
#define BOOK_CATEGORY_RANDOM "Random"
