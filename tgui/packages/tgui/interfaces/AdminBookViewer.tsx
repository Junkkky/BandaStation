import { useBackend } from '../backend';
import { Window } from '../layouts';
import { MarkdownRenderer } from './MarkdownViewer';

type ViewerData = {
  title: string;
  content: string;
  coverImage?: string | null;
  pages?: { text: string; image: string | null; caption: string }[];
  author: string;
  view_raw: boolean;
};

export const AdminBookViewer = (_: any) => {
  const { data } = useBackend<ViewerData>();
  return (
    <Window title={`Reading: ${data.title}`} height={400} width={400}>
      <Window.Content scrollable>
        {!data.view_raw && data.coverImage && (
          <section>
            <h3>Обложка</h3>
            <img
              alt="Обложка книги"
              src={`data:image/png;base64,${data.coverImage}`}
              style={{ maxWidth: '100%' }}
            />
          </section>
        )}
        {data.view_raw ? (
          data.content
        ) : data.pages?.length ? (
          data.pages.map((page, index) => (
            <section key={index}>
              <h3>Страница {index + 1}</h3>
              {page.image && (
                <figure>
                  <img
                    alt={page.caption || 'Иллюстрация'}
                    src={`data:image/png;base64,${page.image}`}
                    style={{ maxWidth: '100%' }}
                  />
                  <figcaption>{page.caption}</figcaption>
                </figure>
              )}
              <MarkdownRenderer content={page.text} />
            </section>
          ))
        ) : (
          <MarkdownRenderer content={data.content} />
        )}
      </Window.Content>
    </Window>
  );
};
