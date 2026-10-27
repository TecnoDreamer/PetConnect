# Requisitos Não Funcionais — PetConnect

Convenção: `RNFxx`.

## Desempenho

| ID | Requisito |
|----|-----------|
| RNF01 | A listagem de pets do tutor deve carregar em até 2s em conexão 4G. |
| RNF02 | A página web pública do QR code deve carregar em até 3s em conexão 3G/4G, já que quem escaneia pode estar na rua com sinal ruim. |
| RNF03 | Upload de foto de pet deve ser comprimido no dispositivo antes do envio, para reduzir consumo de dados e tempo de upload. |

## Disponibilidade e confiabilidade

| ID | Requisito |
|----|-----------|
| RNF04 | O app deve funcionar em modo leitura (visualizar dados já sincronizados) mesmo sem conexão, usando cache local do Firestore. |
| RNF05 | Operações de escrita feitas offline devem ser sincronizadas automaticamente quando a conexão for restabelecida. |
| RNF06 | A página pública do QR code deve ter disponibilidade compatível com SLA do Firebase Hosting/Cloud Functions (o app depende de um serviço de terceiros para essa garantia). |

## Usabilidade

| ID | Requisito |
|----|-----------|
| RNF07 | O fluxo de cadastro de pet (RF10) deve ser completável em no máximo 5 telas/passos. |
| RNF08 | Mensagens de erro (login inválido, campo obrigatório, etc.) devem ser específicas e em português, nunca códigos técnicos crus. |
| RNF09 | O app deve seguir as diretrizes de acessibilidade do Flutter (tamanho de toque mínimo, contraste, suporte a leitor de tela) nas telas principais. |

## Compatibilidade

| ID | Requisito |
|----|-----------|
| RNF10 | O app deve funcionar em Android 8+ e iOS 13+. |
| RNF11 | A página pública do QR code deve funcionar nos navegadores móveis padrão (Chrome, Safari) sem exigir instalação de app. |

## Segurança e privacidade

| ID | Requisito |
|----|-----------|
| RNF12 | Dados de um tutor e de seus pets só podem ser lidos/alterados pelo próprio tutor autenticado (ver `docs/seguranca.md`). |
| RNF13 | O sistema deve estar alinhado à LGPD: finalidade clara da coleta de dados, minimização de dados expostos publicamente (QR code), e possibilidade de exclusão de conta e dados (RF09). |
| RNF14 | Senhas nunca são armazenadas nem transmitidas em texto puro — delegado ao Firebase Authentication. |
| RNF15 | Chaves e credenciais do Firebase não devem ser commitadas no repositório (ver `.gitignore` e `CONTRIBUTING.md`). |

## Manutenibilidade

| ID | Requisito |
|----|-----------|
| RNF16 | O código deve seguir a arquitetura feature-first descrita em `docs/arquitetura.md`, para permitir que múltiplas pessoas trabalhem em features diferentes com baixo conflito de merge. |
| RNF17 | Toda regra de negócio nova deve ter teste automatizado correspondente (unitário ou de widget) antes do merge. |

## Observabilidade

| ID | Requisito |
|----|-----------|
| RNF18 | Erros não tratados no app devem ser registrados (ex: Firebase Crashlytics) para diagnóstico. |

## Galeria de fotos do pet

Ver `docs/features/galeria-fotos-pet.md`.

| ID | Requisito |
|----|-----------|
| RNF19 | A grade carrega miniaturas reduzidas (nunca o original), decodificadas no tamanho exibido, em páginas de 30; a versão maior só ao abrir a foto. |
| RNF20 | Envio com progresso por foto, cancelável, sem duplicar por toque duplo; sucesso parcial informado, com nova tentativa só das que falharam; nunca fica registro apontando para arquivo que não existe. |
| RNF21 | Nenhum segredo do Cloudinary no app; fotos privadas por padrão (só o dono, pelas regras do Firestore), inclusive de pet falecido. |
| RNF22 | A interface só exibe versões transformadas das fotos (sem metadados); o nome original do arquivo não sai do aparelho. |
| RNF23 | Grade, visualizador e envio funcionam nos três temas, com fonte ampliada e em telas a partir de 320 dp, com rótulos para leitor de tela. |
