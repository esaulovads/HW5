FROM python:3.11.13-slim-bookworm AS build
SHELL [ "/bin/sh", "-eu", "-c" ]
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
WORKDIR /build
RUN pip install --no-cache-dir poetry==2.5.1 poetry-plugin-export setuptools wheel
COPY pyproject.toml poetry.lock README.md ./
RUN poetry export --without dev --without-hashes --output requirements.txt \
  && pip wheel --no-cache-dir --wheel-dir /wheels --requirement requirements.txt
COPY src/ src/
RUN poetry build --format wheel


FROM python:3.11.13-slim-bookworm AS final
SHELL [ "/bin/sh", "-eu", "-c" ]
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

ARG USER=user
ARG HOME=/app
ARG UID=1001
ARG GID=1001
RUN \
  addgroup --gid "${GID}" "${USER}" \
  && adduser --disabled-password --gecos "" \
       --home "${HOME}" --ingroup "${USER}" --uid "${UID}" "${USER}" \
  && chage --lastday 2000-01-01 "${USER}" \
  && rm -f /etc/passwd- /etc/group- /etc/shadow- /etc/gshadow-

WORKDIR ${HOME}
COPY --from=build /wheels /wheels
COPY --from=build /build/dist /dist
RUN pip install --no-cache-dir --no-compile --no-index --no-deps /wheels/*.whl /dist/*.whl \
  && rm -rf /wheels /dist

USER ${USER}
EXPOSE 8080/tcp
ENTRYPOINT [ "python", "-m", "audit_svc" ]