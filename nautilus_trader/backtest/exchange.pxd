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

from libc.stdint cimport int64_t

from nautilus_trader.backtest.execution cimport BacktestExecClient
from nautilus_trader.backtest.models cimport FillModel
from nautilus_trader.common.clock cimport Clock
from nautilus_trader.common.logging cimport LoggerAdapter
from nautilus_trader.common.uuid cimport UUIDFactory
from nautilus_trader.execution.cache cimport ExecutionCache
from nautilus_trader.model.c_enums.liquidity_side cimport LiquiditySide
from nautilus_trader.model.c_enums.oms_type cimport OMSType
from nautilus_trader.model.c_enums.order_side cimport OrderSide
from nautilus_trader.model.c_enums.orderbook_level cimport OrderBookLevel
from nautilus_trader.model.c_enums.price_type cimport PriceType
from nautilus_trader.model.commands cimport CancelOrder
from nautilus_trader.model.commands cimport SubmitBracketOrder
from nautilus_trader.model.commands cimport SubmitOrder
from nautilus_trader.model.commands cimport UpdateOrder
from nautilus_trader.model.currency cimport Currency
from nautilus_trader.model.events cimport AccountState
from nautilus_trader.model.identifiers cimport ClientOrderId
from nautilus_trader.model.identifiers cimport ExecutionId
from nautilus_trader.model.identifiers cimport InstrumentId
from nautilus_trader.model.identifiers cimport PositionId
from nautilus_trader.model.identifiers cimport Venue
from nautilus_trader.model.identifiers cimport VenueOrderId
from nautilus_trader.model.objects cimport Money
from nautilus_trader.model.objects cimport Price
from nautilus_trader.model.objects cimport Quantity
from nautilus_trader.model.order.base cimport Order
from nautilus_trader.model.order.base cimport PassiveOrder
from nautilus_trader.model.order.limit cimport LimitOrder
from nautilus_trader.model.order.market cimport MarketOrder
from nautilus_trader.model.order.stop_limit cimport StopLimitOrder
from nautilus_trader.model.order.stop_market cimport StopMarketOrder
from nautilus_trader.model.orderbook.book cimport OrderBook
from nautilus_trader.model.orderbook.book cimport OrderBookData
from nautilus_trader.model.tick cimport Tick
from nautilus_trader.trading.calculators cimport ExchangeRateCalculator


cdef class SimulatedExchange:
    cdef Clock _clock
    cdef UUIDFactory _uuid_factory
    cdef LoggerAdapter _log

    cdef readonly Venue id
    """The exchange identifier.\n\n:returns: `Venue`"""
    cdef readonly OMSType oms_type
    """The exchange order management system type.\n\n:returns: `OMSType`"""
    cdef readonly OrderBookLevel exchange_order_book_level
    """The exchange default order book level.\n\n:returns: `OrderBookLevel`"""
    cdef readonly ExecutionCache exec_cache
    """The execution cache wired to the exchange.\n\n:returns: `ExecutionCache`"""
    cdef readonly BacktestExecClient exec_client
    """The execution client wired to the exchange.\n\n:returns: `BacktestExecClient`"""

    cdef readonly bint is_frozen_account
    """If the account for the exchange is frozen.\n\n:returns: `bool`"""
    cdef readonly list starting_balances
    """The account starting balances for each backtest run.\n\n:returns: `bool`"""
    cdef readonly Currency default_currency
    """The account default currency.\n\n:returns: `Currency` or None"""
    cdef readonly dict account_balances
    """The current account balances.\n\n:returns: `dict[Currency, Money]`"""
    cdef readonly dict account_balances_free
    """The current account balances free.\n\n:returns: `dict[Currency, Money]`"""
    cdef readonly dict account_balances_locked
    """The current account balances locked.\n\n:returns: `dict[Currency, Money]`"""
    cdef readonly dict total_commissions
    """The total commissions generated with the exchange.\n\n:returns: `dict[Currency, Money]`"""

    cdef readonly ExchangeRateCalculator xrate_calculator
    """The exchange rate calculator for the exchange.\n\n:returns: `ExchangeRateCalculator`"""
    cdef readonly FillModel fill_model
    """The fill model for the exchange.\n\n:returns: `FillModel`"""
    cdef readonly list modules
    """The simulation modules registered with the exchange.\n\n:returns: `list[SimulationModule]`"""
    cdef readonly dict instruments
    """The exchange instruments.\n\n:returns: `dict[InstrumentId, Instrument]`"""

    cdef dict _books
    cdef dict _instrument_orders
    cdef dict _working_orders
    cdef dict _position_index
    cdef dict _child_orders
    cdef dict _oco_orders
    cdef dict _position_oco_orders
    cdef dict _instrument_indexer
    cdef dict _symbol_pos_count
    cdef dict _symbol_ord_count
    cdef int _executions_count

    cpdef Price best_bid_price(self, InstrumentId instrument_id)
    cpdef Price best_ask_price(self, InstrumentId instrument_id)
    cpdef object get_xrate(self, Currency from_currency, Currency to_currency, PriceType price_type)
    cpdef OrderBook get_book(self, InstrumentId instrument_id)
    cpdef dict get_books(self)
    cpdef dict get_working_orders(self)

    cpdef void register_client(self, BacktestExecClient client) except *
    cpdef void set_fill_model(self, FillModel fill_model) except *
    cpdef void initialize_account(self) except *
    cpdef void adjust_account(self, Money adjustment) except *
    cpdef void process_order_book(self, OrderBookData data) except *
    cpdef void process_tick(self, Tick tick) except *
    cpdef void process_modules(self, int64_t now_ns) except *
    cpdef void check_residuals(self) except *
    cpdef void reset(self) except *

# -- COMMAND HANDLERS ------------------------------------------------------------------------------

    cpdef void handle_submit_order(self, SubmitOrder command) except *
    cpdef void handle_submit_bracket_order(self, SubmitBracketOrder command) except *
    cpdef void handle_update_order(self, UpdateOrder command) except *
    cpdef void handle_cancel_order(self, CancelOrder command) except *

# --------------------------------------------------------------------------------------------------

    cdef inline dict _build_current_bid_rates(self)
    cdef inline dict _build_current_ask_rates(self)
    cdef inline PositionId _generate_position_id(self, InstrumentId instrument_id)
    cdef inline VenueOrderId _generate_order_id(self, InstrumentId instrument_id)
    cdef inline ExecutionId _generate_execution_id(self)
    cdef inline AccountState _generate_account_event(self)

# -- EVENT HANDLING --------------------------------------------------------------------------------

    cdef inline void _submit_order(self, Order order) except *
    cdef inline void _accept_order(self, Order order) except *
    cdef inline void _reject_order(self, Order order, str reason) except *
    cdef inline void _update_order(self, ClientOrderId client_order_id, Quantity qty, Price price) except *
    cdef inline void _cancel_order(self, ClientOrderId client_order_id) except *
    cdef inline void _reject_cancel(self, ClientOrderId client_order_id, str response, str reason) except *
    cdef inline void _reject_update(self, ClientOrderId client_order_id, str response, str reason) except *
    cdef inline void _expire_order(self, PassiveOrder order) except *
    cdef inline void _trigger_order(self, StopLimitOrder order) except *
    cdef inline void _process_order(self, Order order) except *
    cdef inline void _process_market_order(self, MarketOrder order) except *
    cdef inline void _process_limit_order(self, LimitOrder order) except *
    cdef inline void _process_stop_market_order(self, StopMarketOrder order) except *
    cdef inline void _process_stop_limit_order(self, StopLimitOrder order) except *
    cdef inline void _update_limit_order(self, LimitOrder order, Quantity qty, Price price) except *
    cdef inline void _update_stop_market_order(self, StopMarketOrder order, Quantity qty, Price price) except *
    cdef inline void _update_stop_limit_order(self, StopLimitOrder order, Quantity qty, Price price) except *
    cdef inline void _generate_order_updated(self, PassiveOrder order, Quantity qty, Price price) except *
    cdef inline void _add_order(self, PassiveOrder order) except *
    cdef inline void _delete_order(self, Order order) except *

# -- ORDER MATCHING ENGINE -------------------------------------------------------------------------

    cdef inline void _iterate_matching_engine(self, InstrumentId instrument_id, int64_t timestamp_ns) except *
    cdef inline void _match_order(self, PassiveOrder order) except *
    cdef inline void _match_limit_order(self, LimitOrder order) except *
    cdef inline void _match_stop_market_order(self, StopMarketOrder order) except *
    cdef inline void _match_stop_limit_order(self, StopLimitOrder order) except *
    cdef inline bint _is_limit_marketable(self, InstrumentId instrument_id, OrderSide side, Price price) except *
    cdef inline bint _is_limit_matched(self, InstrumentId instrument_id, OrderSide side, Price price) except *
    cdef inline bint _is_stop_marketable(self, InstrumentId instrument_id, OrderSide side, Price price) except *
    cdef inline bint _is_stop_triggered(self, InstrumentId instrument_id, OrderSide side, Price price) except *
    cdef inline list _determine_limit_price_and_volume(self, PassiveOrder order)
    cdef inline list _determine_market_price_and_volume(self, Order order)

# --------------------------------------------------------------------------------------------------

    cdef inline void _passively_fill_order(self, PassiveOrder order, LiquiditySide liquidity_side) except *
    cdef inline void _aggressively_fill_order(self, Order order, LiquiditySide liquidity_side) except *
    cdef inline void _fill_order(self, Order order, Price last_px, Quantity last_qty, LiquiditySide liquidity_side) except *
    cdef inline void _clean_up_child_orders(self, ClientOrderId client_order_id) except *
    cdef inline void _check_oco_order(self, ClientOrderId client_order_id) except *
    cdef inline void _reject_oco_order(self, PassiveOrder order, ClientOrderId other_oco) except *
    cdef inline void _cancel_oco_order(self, PassiveOrder order) except *
