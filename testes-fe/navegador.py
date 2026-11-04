from contextlib import contextmanager  # permite usar a função em um bloco "with"
from pathlib import Path  # manipulação de caminhos de arquivo de forma portável
from typing import Iterator, Optional  # tipos para deixar a leitura mais clara

from playwright.sync_api import Page, sync_playwright

from configuracao import ConfiguracaoTeste

@contextmanager
def abrir_navegador(
    configuracao: Optional[ConfiguracaoTeste] = None,
) -> Iterator[Page]:
    """Abre o navegador e devolve a aba (Page) pronta para uso.

    Uso:
        with abrir_navegador() as pagina:
            ...

    Sempre fecha o navegador no final, evitando processos "zumbis" no SO.
    """
    # Se nenhuma configuração for informada, usa os valores padrão.
    config = configuracao or ConfiguracaoTeste()

    # Valida a configuração antes de tentar abrir qualquer coisa.
    config.validar()

    # O "with sync_playwright()" inicializa e encerra a engine do Playwright.
    # Ele precisa envolver TODO o uso do navegador.
    with sync_playwright() as playwright:
        # Pega a engine escolhida na configuração: p.chromium / p.firefox / p.webkit.
        # getattr permite escolher pelo nome (string), sem vários ifs.
        engine = getattr(playwright, config.navegador)

        # Monta os argumentos do launch. headless é sempre usado;
        # channel só é passado quando a configuração pedir (msedge/chrome).
        argumentos = {"headless": config.headless}
        if config.canal:
            argumentos["channel"] = config.canal  # ex.: "chrome"

        # Abre o navegador. Se o navegador/canal não estiver instalado, o
        # Playwright lança um erro dizendo qual comando rodar.
        navegador = engine.launch(**argumentos)

        # Cria uma aba nova já com o tamanho de janela configurado.
        pagina = navegador.new_page(viewport=config.viewport)

        # Tempo máximo padrão para cada ação (evita esperas infinitas).
        pagina.set_default_timeout(config.timeout_padrao_ms)

        try:
            # Entrega a aba para o teste. Quem chamou usa o que quiser aqui.
            yield pagina
        finally:
            # Fecha SEMPRE o navegador, com sucesso ou com falha no teste.
            navegador.close()


def capturar_tela(pagina: Page, caminho: str) -> None:
    """Salva um print da tela atual no caminho informado.

    Além de tirar o print, cria a pasta de destino caso ela não exista — assim
    o "salvamento da evidência" não pode ser a causa de um segundo erro.
    """
    # Converte a string em Path para poder navegar entre pastas com facilidade.
    destino = Path(caminho)

    # Cria a pasta (e as pastas "pai"), sem reclamar se ela já existir.
    destino.parent.mkdir(parents=True, exist_ok=True)

    pagina.screenshot(path=str(destino))
