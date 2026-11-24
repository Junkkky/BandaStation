import { useState } from 'react';
import { formatMoney } from 'tgui-core/format';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type TradeRequest = {
  id: string;
  name: string;
  status: 'open' | 'restocking' | 'renewing';
  quantity: number | null;
  unit_reward?: number;
  high_demand?: BooleanLike;
  rate_percent?: number;
  rate_seconds_left?: number;
};

type TradeHub = {
  id: string;
  name: string;
  problem: string | null;
  requests: TradeRequest[];
};

type TradeReport = {
  sector: string | null;
  hubs: TradeHub[] | null;
  age_seconds: number | null;
  refresh_seconds: number;
};

function clock(seconds: number) {
  const minutes = Math.floor(seconds / 60);
  return `${minutes}:${String(seconds % 60).padStart(2, '0')}`;
}

function acceptance(request: TradeRequest, hubUnavailable: boolean) {
  if (hubUnavailable) {
    return 'Приём закрыт';
  }
  if (request.status === 'renewing') {
    return 'Смена заявки';
  }
  if (request.status === 'restocking') {
    return 'Партия принята';
  }
  return request.quantity === null ? 'Без лимита' : `${request.quantity} ед.`;
}

export function SectorTradeMonitor() {
  const { act, data } = useBackend<TradeReport>();
  const { sector, hubs, age_seconds, refresh_seconds } = data;
  const [query, setQuery] = useState('');
  const search = query.trim().toLocaleLowerCase('ru');
  const matchingHubs = (hubs ?? [])
    .map((hub) => ({
      ...hub,
      requests:
        !search || hub.name.toLocaleLowerCase('ru').includes(search)
          ? hub.requests
          : hub.requests.filter((request) =>
              request.name.toLocaleLowerCase('ru').includes(search),
            ),
    }))
    .filter((hub) => hub.requests.length > 0);

  return (
    <Window title="Торговые заявки" width={670} height={570} theme="trade-hub">
      <Window.Content fitted className="SectorTradeMonitor">
        <header className="SectorTradeMonitor__toolbar">
          <div className="SectorTradeMonitor__sector">
            <strong>{sector ?? 'Сектор недоступен'}</strong>
            <span className="SectorTradeMonitor__muted">
              {age_seconds == null
                ? 'Сводка ещё не получена'
                : `Сводка получена ${clock(age_seconds)} назад`}
            </span>
          </div>
          <div className="SectorTradeMonitor__refresh">
            <button
              type="button"
              disabled={!sector || refresh_seconds > 0}
              onClick={() => act('refresh')}
            >
              {age_seconds == null ? 'Запросить сводку' : 'Обновить сводку'}
            </button>
            <span className="SectorTradeMonitor__muted">
              {refresh_seconds > 0
                ? `Доступно через ${clock(refresh_seconds)}`
                : 'Интервал — 5 минут'}
            </span>
          </div>
          {!!hubs?.length && (
            <input
              aria-label="Поиск по товару или узлу"
              placeholder="Поиск по товару или узлу"
              type="search"
              value={query}
              onChange={(event) => setQuery(event.currentTarget.value)}
            />
          )}
        </header>
        <div className="SectorTradeMonitor__body">
          {!sector ? (
            <p>Нет связи с сектором станции. Проверьте консоль позже.</p>
          ) : age_seconds == null ? (
            <p>Запросите сводку, чтобы увидеть цены и объёмы приёма по узлам.</p>
          ) : !hubs?.length ? (
            <p>В секторе нет торговых узлов, передавших заявки.</p>
          ) : !matchingHubs.length ? (
            <p>Совпадений нет. Измените запрос, чтобы найти товар или узел.</p>
          ) : (
            <table aria-label="Торговые заявки по узлам">
              <thead>
                <tr>
                  <th scope="col">Товар</th>
                  <th scope="col">К приёму</th>
                  <th scope="col">Выплата</th>
                </tr>
              </thead>
              {matchingHubs.map((hub) => (
                <tbody key={hub.id}>
                  <tr className="SectorTradeMonitor__hub">
                    <th colSpan={3} scope="rowgroup">
                      {hub.name}
                      {hub.problem && <small>{hub.problem}</small>}
                    </th>
                  </tr>
                  {hub.requests.map((request) => (
                    <tr key={request.id}>
                      <th scope="row">
                        {request.name}
                        {!!request.high_demand && (
                          <small className="SectorTradeMonitor__premium">
                            Высокий спрос
                          </small>
                        )}
                      </th>
                      <td>{acceptance(request, !!hub.problem)}</td>
                      <td>
                        {request.rate_percent === undefined ? (
                          formatMoney(request.unit_reward ?? 0) + ' кр./ед.'
                        ) : (
                          <>
                            {request.rate_percent}%
                            {age_seconds >= (request.rate_seconds_left ?? 0) && (
                              <small>Курс истёк</small>
                            )}
                          </>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              ))}
            </table>
          )}
        </div>
      </Window.Content>
    </Window>
  );
}
