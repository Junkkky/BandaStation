import { expect, it, spyOn } from 'bun:test';
import { chatRenderer } from './renderer';

it('exports chat without external portraits while preserving the live message', async () => {
  const node = document.createElement('div');
  node.innerHTML =
    "<span>Описание</span><img class='examine-portrait' src='https://i.gyazo.com/portrait.png'><img class='icon' src='sprite.png'>";
  const previousMessages = chatRenderer.visibleMessages;
  const saveBlob = spyOn(Byond, 'saveBlob').mockImplementation(() => {});
  chatRenderer.visibleMessages = [{ node }];
  try {
    chatRenderer.saveToDisk();
    const html = await saveBlob.mock.calls[0][0].text();
    expect(html).toContain('Описание');
    expect(html).toContain('sprite.png');
    expect(html).not.toContain('https://i.gyazo.com/portrait.png');
    expect(node.querySelector('img.examine-portrait')).not.toBeNull();
  } finally {
    chatRenderer.visibleMessages = previousMessages;
    saveBlob.mockRestore();
  }
});
