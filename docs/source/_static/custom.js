document.addEventListener('DOMContentLoaded', () => {
  const blocks = document.querySelectorAll('div.highlight');

  // 定义几个简单的小图标（SVG）
  const copyIcon = `
    <svg viewBox="0 0 20 20" width="16" height="16" aria-hidden="true">
      <rect x="7" y="3" width="9" height="13" rx="2" ry="2" fill="none" stroke="currentColor" stroke-width="1.4"/>
      <rect x="4" y="6" width="9" height="11" rx="2" ry="2" fill="none" stroke="currentColor" stroke-width="1.4" opacity="0.7"/>
    </svg>
  `;
  const copiedIcon = `
    <svg viewBox="0 0 20 20" width="16" height="16" aria-hidden="true">
      <circle cx="10" cy="10" r="8" fill="none" stroke="currentColor" stroke-width="1.5"/>
      <path d="M6 10.5 L8.5 13 L14 7" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
    </svg>
  `;
  const errorIcon = `
    <svg viewBox="0 0 20 20" width="16" height="16" aria-hidden="true">
      <circle cx="10" cy="10" r="8" fill="none" stroke="currentColor" stroke-width="1.5"/>
      <line x1="10" y1="6" x2="10" y2="11" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
      <circle cx="10" cy="14" r="1" fill="currentColor"/>
    </svg>
  `;

  blocks.forEach((block) => {
    const pre = block.querySelector('pre');
    if (!pre) return;

    // 包一层，方便放置右上角按钮
    const wrapper = document.createElement('div');
    wrapper.className = 'code-block-wrapper';
    block.parentNode.insertBefore(wrapper, block);
    wrapper.appendChild(block);

    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'copy-code-btn';
    btn.innerHTML = copyIcon;               // 用图标而不是文字
    btn.setAttribute('aria-label', '复制代码');  // 给屏幕阅读器用
    wrapper.appendChild(btn);

    btn.addEventListener('click', async () => {
      const text = pre.innerText;
      try {
        await navigator.clipboard.writeText(text);
        btn.innerHTML = copiedIcon;
        setTimeout(() => {
          btn.innerHTML = copyIcon;
        }, 1600);
      } catch (err) {
        btn.innerHTML = errorIcon;
        setTimeout(() => {
          btn.innerHTML = copyIcon;
        }, 1600);
      }
    });
  });
});
