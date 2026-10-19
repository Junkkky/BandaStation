document.addEventListener('keydown', function (event) {
  if (event.keyCode === 32 && (' ' + event.target.className + ' ').indexOf(' pump-switch ') !== -1) {
    event.preventDefault();
    event.target.click();
  }
});
