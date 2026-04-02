const ClipboardCopy = {
  mounted() {
    this.el.addEventListener("click", () => {
      const url = this.el.dataset.url;
      navigator.clipboard.writeText(url).then(() => {
        const orig = this.el.textContent;
        this.el.textContent = "Copiado!";
        setTimeout(() => { this.el.textContent = orig; }, 1500);
      });
    });
  }
}

export default ClipboardCopy;