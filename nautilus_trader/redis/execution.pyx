# -------------------------------------------------------------------------------------------------
#  Copyright (C) 2015-2021 Nautech Systems Pty Ltd. All rights reserved.
#  https://nautechsystems.io
#
#  Licensed under the GNU Lesser General Public License Version 3.0 (the "License");
#  You may not use this file except in compliance with the License.
#  You may obtain a copy of the License at https://www.gnu.org/licenses/lgpl-3.0.en.html
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
# -------------------------------------------------------------------------------------------------

import redis

from nautilus_trader.common.logging cimport Logger
from nautilus_trader.core.correctness cimport Condition
from nautilus_trader.execution.database cimport ExecutionDatabase
from nautilus_trader.model.c_enums.order_type cimport OrderType
from nautilus_trader.model.events cimport OrderFilled
from nautilus_trader.model.events cimport OrderInitialized
from nautilus_trader.model.identifiers cimport AccountId
from nautilus_trader.model.identifiers cimport ClientOrderId
from nautilus_trader.model.identifiers cimport PositionId
from nautilus_trader.model.identifiers cimport StrategyId
from nautilus_trader.model.identifiers cimport TraderId
from nautilus_trader.model.order.base cimport Order
from nautilus_trader.model.order.limit cimport LimitOrder
from nautilus_trader.model.order.market cimport MarketOrder
from nautilus_trader.model.order.stop_limit cimport StopLimitOrder
from nautilus_trader.model.order.stop_market cimport StopMarketOrder
from nautilus_trader.model.position cimport Position
from nautilus_trader.serialization.base cimport CommandSerializer
from nautilus_trader.serialization.serializers cimport EventSerializer
from nautilus_trader.trading.account cimport Account
from nautilus_trader.trading.strategy cimport TradingStrategy


cdef str _UTF8 = 'utf-8'
cdef str _ACCOUNTS = 'Accounts'
cdef str _TRADER = 'Trader'
cdef str _ORDERS = 'Orders'
cdef str _POSITIONS = 'Positions'
cdef str _STRATEGIES = 'Strategies'


cdef class RedisExecutionDatabase(ExecutionDatabase):
    """
    Provides an execution database backed by Redis.

    """

    def __init__(
        self,
        TraderId trader_id not None,
        Logger logger not None,
        CommandSerializer command_serializer not None,
        EventSerializer event_serializer not None,
        dict config,
    ):
        """
        Initialize a new instance of the `RedisExecutionDatabase` class.

        Parameters
        ----------
        trader_id : TraderId
            The trader identifier for the database.
        logger : Logger
            The logger for the database.
        command_serializer : CommandSerializer
            The command serializer for cache transactions.
        event_serializer : EventSerializer
            The event serializer for cache transactions.

        Raises
        ------
        ValueError
            If the host is not a valid string.
        ValueError
            If the port is not in range [0, 65535].

        """
        cdef str host = config["host"]
        cdef int port = int(config["port"])
        Condition.valid_string(host, "host")
        Condition.in_range_int(port, 0, 65535, "port")
        super().__init__(trader_id, logger)

        # Database keys
        self._key_trader     = f"{_TRADER}-{trader_id.value}"        # noqa
        self._key_accounts   = f"{self._key_trader}:{_ACCOUNTS}:"    # noqa
        self._key_orders     = f"{self._key_trader}:{_ORDERS}:"      # noqa
        self._key_positions  = f"{self._key_trader}:{_POSITIONS}:"   # noqa
        self._key_strategies = f"{self._key_trader}:{_STRATEGIES}:"  # noqa

        # Serializers
        self._command_serializer = command_serializer
        self._event_serializer = event_serializer

        # Redis client
        self._redis = redis.Redis(host=host, port=port, db=0)

# -- COMMANDS --------------------------------------------------------------------------------------

    cpdef void flush(self) except *:
        """
        Flush the database which clears all data.

        """
        self._log.debug("Flushing database....")
        self._redis.flushdb()
        self._log.info("Flushed database.")

    cpdef dict load_accounts(self):
        """
        Load all accounts from the execution database.

        Returns
        -------
        dict[AccountId, Account]

        """
        cdef dict accounts = {}

        cdef list account_keys = self._redis.keys(f"{self._key_accounts}*")
        if not account_keys:
            return accounts

        cdef bytes key_bytes
        cdef AccountId account_id
        cdef Account account
        for key_bytes in account_keys:
            account_id = AccountId.from_str_c(key_bytes.decode(_UTF8).rsplit(':', maxsplit=1)[1])
            account = self.load_account(account_id)

            if account is not None:
                accounts[account.id] = account

        return accounts

    cpdef dict load_orders(self):
        """
        Load all orders from the execution database.

        Returns
        -------
        dict[ClientOrderId, Order]

        """
        cdef dict orders = {}

        cdef list order_keys = self._redis.keys(f"{self._key_orders}*")
        if not order_keys:
            return orders

        cdef bytes key_bytes
        cdef ClientOrderId client_order_id
        cdef Order order
        for key_bytes in order_keys:
            client_order_id = ClientOrderId(key_bytes.decode(_UTF8).rsplit(':', maxsplit=1)[1])
            order = self.load_order(client_order_id)

            if order is not None:
                orders[order.client_order_id] = order

        return orders

    cpdef dict load_positions(self):
        """
        Load all positions from the execution database.

        Returns
        -------
        dict[PositionId, Position]

        """
        cdef dict positions = {}

        cdef list position_keys = self._redis.keys(f"{self._key_positions}*")
        if not position_keys:
            return positions

        cdef bytes key_bytes
        cdef PositionId position_id
        cdef Position position
        for key_bytes in position_keys:
            position_id = PositionId(key_bytes.decode(_UTF8).rsplit(':', maxsplit=1)[1])
            position = self.load_position(position_id)

            if position is not None:
                positions[position.id] = position

        return positions

    cpdef Account load_account(self, AccountId account_id):
        """
        Load the account associated with the given account_id (if found).

        Parameters
        ----------
        account_id : AccountId
            The account identifier to load.

        Returns
        -------
        Account or None

        """
        Condition.not_none(account_id, "account_id")

        cdef list events = self._redis.lrange(name=self._key_accounts + account_id.value, start=0, end=-1)
        if not events:
            return None

        cdef bytes event
        cdef Account account = Account(self._event_serializer.deserialize(events[0]))
        for event in events[1:]:
            account.apply(event=self._event_serializer.deserialize(event))

        return account

    cpdef Order load_order(self, ClientOrderId client_order_id):
        """
        Load the order associated with the given identifier (if found).

        Parameters
        ----------
        client_order_id : ClientOrderId
            The client order identifier to load.

        Returns
        -------
        Order or None

        """
        Condition.not_none(client_order_id, "client_order_id")

        cdef list events = self._redis.lrange(name=self._key_orders + client_order_id.value, start=0, end=-1)

        # Check there is at least one event to pop
        if not events:
            return None

        cdef OrderInitialized init = self._event_serializer.deserialize(events.pop(0))

        cdef Order order
        if init.order_type == OrderType.MARKET:
            order = MarketOrder.create(init=init)
        elif init.order_type == OrderType.LIMIT:
            order = LimitOrder.create(init=init)
        elif init.order_type == OrderType.STOP_MARKET:
            order = StopMarketOrder.create(init=init)
        elif init.order_type == OrderType.STOP_LIMIT:
            order = StopLimitOrder.create(init=init)
        else:
            raise RuntimeError("Invalid order type")

        cdef bytes event_bytes
        for event_bytes in events:
            order.apply(self._event_serializer.deserialize(event_bytes))

        return order

    cpdef Position load_position(self, PositionId position_id):
        """
        Load the position associated with the given identifier (if found).

        Parameters
        ----------
        position_id : PositionId
            The position identifier to load.

        Returns
        -------
        Position or None

        """
        Condition.not_none(position_id, "position_id")

        cdef list events = self._redis.lrange(name=self._key_positions + position_id.value, start=0, end=-1)

        # Check there is at least one event to pop
        if not events:
            return None

        cdef OrderFilled initial_fill = self._event_serializer.deserialize(events.pop(0))
        cdef Position position = Position(fill=initial_fill)

        cdef bytes event_bytes
        for event_bytes in events:
            position.apply(self._event_serializer.deserialize(event_bytes))

        return position

    cpdef dict load_strategy(self, StrategyId strategy_id):
        """
        Load the state for the given strategy.

        Parameters
        ----------
        strategy_id : StrategyId
            The identifier of the strategy state dictionary to load.

        Returns
        -------
        dict[str, bytes]

        """
        Condition.not_none(strategy_id, "strategy_id")

        cdef dict user_state = self._redis.hgetall(name=self._key_strategies + strategy_id.value + ":State")
        return {k.decode('utf-8'): v for k, v in user_state.items()}

    cpdef void delete_strategy(self, StrategyId strategy_id) except *:
        """
        Delete the given strategy from the execution cache.
        Logs error if strategy not found in the cache.

        Parameters
        ----------
        strategy_id : StrategyId
            The identifier of the strategy state dictionary to delete.

        """
        Condition.not_none(strategy_id, "strategy_id")

        self._redis.delete(self._key_strategies + strategy_id.value)

        self._log.info(f"Deleted {repr(strategy_id)}.")

    cpdef void add_account(self, Account account) except *:
        """
        Add the given account to the execution cache.

        Parameters
        ----------
        account : Account
            The account to add.

        """
        Condition.not_none(account, "account")

        # Command pipeline
        pipe = self._redis.pipeline()
        pipe.rpush(self._key_accounts + account.id.value, self._event_serializer.serialize(account.last_event_c()))
        cdef list reply = pipe.execute()

        # Check data integrity of reply
        if len(reply) > 1:  # Reply = The length of the list after the push operation
            self._log.error(f"The {account.id} already existed in the accounts and was appended to.")

        self._log.debug(f"Added Account(id={account.id.value}).")

    cpdef void add_order(self, Order order) except *:
        """
        Add the given order to the execution cache indexed with the given
        identifiers.

        Parameters
        ----------
        order : Order
            The order to add.

        """
        Condition.not_none(order, "order")

        cdef bytes last_event = self._event_serializer.serialize(order.last_event_c())
        cdef int reply = self._redis.rpush(self._key_orders + order.client_order_id.value, last_event)

        # Check data integrity of reply
        if reply > 1:  # Reply = The length of the list after the push operation
            self._log.error(f"The {order.client_order_id} already existed in the orders and was appended to.")

    cpdef void add_position(self, Position position) except *:
        """
        Add the given position associated with the given strategy identifier.

        Parameters
        ----------
        position : Position
            The position to add.

        """
        Condition.not_none(position, "position")

        cdef bytes last_event = self._event_serializer.serialize(position.last_event_c())
        cdef int reply = self._redis.rpush(self._key_positions + position.id.value, last_event)

        # Check data integrity of reply
        if reply > 1:  # Reply = The length of the list after the push operation
            self._log.error(f"The {position.id} already existed in the index_broker_position and was overwritten.")

        self._log.debug(f"Added Position(id={position.id.value}).")

    cpdef void update_strategy(self, TradingStrategy strategy) except *:
        """
        Update the given strategy state in the execution cache.

        Parameters
        ----------
        strategy : TradingStrategy
            The strategy to update.

        """
        Condition.not_none(strategy, "strategy")

        cdef dict state = strategy.save()  # Extract state dictionary from strategy

        # Command pipeline
        pipe = self._redis.pipeline()
        for key, value in state.items():
            pipe.hset(name=self._key_strategies + strategy.id.value + ":State", key=key, value=value)
            self._log.debug(f"Saving {strategy.id} state {{ {key}: {value} }}")
        pipe.execute()

        self._log.debug(f"Saved strategy state for {strategy.id.value}.")

    cpdef void update_account(self, Account account) except *:
        """
        Update the given account in the execution cache.

        Parameters
        ----------
        account : The account to update (from last event).

        """
        Condition.not_none(account, "account")

        cdef bytes serialized_event = self._event_serializer.serialize(account.last_event_c())
        self._redis.rpush(self._key_accounts + account.id.value, serialized_event)

        self._log.debug(f"Updated Account(id={account.id}).")

    cpdef void update_order(self, Order order) except *:
        """
        Update the given order in the execution cache.

        Parameters
        ----------
        order : Order
            The order to update (from last event).

        """
        Condition.not_none(order, "order")

        cdef bytes serialized_event = self._event_serializer.serialize(order.last_event_c())
        cdef int reply = self._redis.rpush(self._key_orders + order.client_order_id.value, serialized_event)

        # Check data integrity of reply
        if reply == 1:  # Reply = The length of the list after the push operation
            self._log.error(f"The updated Order(id={order.client_order_id.value}) did not already exist.")

        self._log.debug(f"Updated Order(id={order.client_order_id.value}).")

    cpdef void update_position(self, Position position) except *:
        """
        Update the given position in the execution cache.

        Parameters
        ----------
        position : Position
            The position to update (from last event).

        """
        Condition.not_none(position, "position")

        cdef bytes serialized_event = self._event_serializer.serialize(position.last_event_c())
        cdef int reply = self._redis.rpush(self._key_positions + position.id.value, serialized_event)

        # Check data integrity of reply
        if reply == 1:  # Reply = The length of the list after the push operation
            self._log.error(f"The updated Position(id={position.id.value}) did not already exist.")

        self._log.debug(f"Updated Position(id={position.id.value}).")
