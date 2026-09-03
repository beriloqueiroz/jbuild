# jbuild

CLI mínima para Jenkins multibranch: dispara builds com parâmetros, acompanha a
execução etapa a etapa ao vivo e puxa o log da etapa que falhou — direto do
terminal, com tab-completion no zsh.

Nasceu de uma tarde em que o dashboard exigia cliques demais.

## O que tem

- **`jenkins-jobs-update`** — varre a árvore do Jenkins pela API e reescreve
  `~/.jenkins-jobs.json` com apelidos, branches e os parâmetros de cada branch.
- **`jbuild <job> [branch] [ação] [PARAM=valor ...]`** — resolve o apelido e age
  na branch (default `sandbox`).
- **`_jbuild`** — completion do zsh que lê o cache: completa job, branch, ação e
  **os valores válidos de cada parâmetro**.

## Ações

| ação | o que faz |
|---|---|
| `build` (default) | dispara e já acompanha ao vivo; ao terminar, se falhou, imprime o log da etapa que quebrou |
| `watch` | acompanha o último build ao vivo, no estilo `gh run watch` |
| `status` | resultado do último build numa linha |
| `stages` | etapas do último build, com duração |
| `log [etapa]` | console completo (últimas N linhas) ou o log de uma etapa |
| `params` | parâmetros da branch, com opções e default |

Flags: `-y` (não pede confirmação), `--no-watch`, `-n <linhas>`,
`-b <número do build>`.

## Requisitos

`python3` (só stdlib) e, para o completion, zsh. Sem `curl`, sem
`jenkins-cli.jar`, sem Java — tudo via API REST.

O detalhe por etapa depende do plugin **pipeline-graph-view** no Jenkins. Sem
ele, `build`/`status`/`log` seguem funcionando e `watch`/`stages` avisam que não
há detalhe disponível.

## Instalação

```bash
git clone https://github.com/beriloqueiroz/jbuild && cd jbuild
./install.sh
```

Depois:

1. Edite `~/.jbuildrc` com a URL do seu Jenkins.
2. Gere um API token no Jenkins (avatar → *Security* → *API Token*) e registre
   no `~/.netrc` (`chmod 600`):

   ```
   machine jenkins.exemplo.com
     login seu-user-id
     password seu-token
   ```

   Atenção: o *user id* do Jenkins nem sempre é o e-mail — confira na URL do seu
   perfil (`/user/<id>/`).

3. `jenkins-jobs-update` e pronto.

## Uso

```bash
jbuild billingapi                            # build da sandbox, acompanhando
jbuild billingworker sandbox params          # o que dá pra parametrizar
jbuild billingworker sandbox build SERVICE_TARGET=alerts-worker
jbuild billingworker -y --no-watch           # dispara e sai
jbuild portalweb sandbox watch               # acompanha o build em andamento
jbuild portalweb sandbox stages              # etapas do último build
jbuild portalweb sandbox log Deploy          # log só da etapa Deploy
jbuild portalweb sandbox stages -b 352       # um build específico
jenkins-jobs-update                          # re-descobre jobs e parâmetros
```

Valores de parâmetro são validados contra as opções da branch **antes** de
disparar — as opções podem diferir entre branches, e o erro aparece no terminal
em vez de virar um build vermelho.

O apelido aceita prefixo único: `jbuild billingw` resolve `billingworker`.

## Config (`~/.jbuildrc`)

| chave | default | para quê |
|---|---|---|
| `JENKINS_URL` | — (obrigatória) | URL base do Jenkins |
| `JBUILD_DEFAULT_BRANCH` | `sandbox` | branch quando você não passa uma |
| `JBUILD_STRIP_PREFIXES` | vazio | prefixos removidos dos apelidos (ex.: `plataforma-`) |
| `JBUILD_LOG_LINES` | `60` | linhas do `log` |
| `JBUILD_POLL_SECONDS` | `3` | intervalo do `watch` |
| `JBUILD_JOBS_FILE` | `~/.jenkins-jobs.json` | onde vive o cache de jobs |

## Licença

MIT.
