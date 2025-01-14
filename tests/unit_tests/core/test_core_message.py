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

import pytest

from nautilus_trader.core.message import Document
from nautilus_trader.core.message import Message
from nautilus_trader.core.message import MessageType
from nautilus_trader.core.message import Response
from nautilus_trader.core.message import message_type_from_str
from nautilus_trader.core.message import message_type_to_str
from nautilus_trader.core.uuid import uuid4


class TestMessage:
    def test_message_equality(self):
        # Arrange
        uuid = uuid4()

        message1 = Message(
            msg_type=MessageType.COMMAND,
            identifier=uuid,
            timestamp_ns=0,
        )

        message2 = Message(
            msg_type=MessageType.COMMAND,
            identifier=uuid,
            timestamp_ns=0,
        )

        message3 = Message(
            msg_type=MessageType.DOCUMENT,  # Different message type
            identifier=uuid,
            timestamp_ns=0,
        )

        message4 = Message(
            msg_type=MessageType.DOCUMENT,
            identifier=uuid4(),  # Different UUID
            timestamp_ns=0,
        )

        # Act
        # Assert
        assert message1 == message1
        assert message1 == message2
        assert message1 != message3
        assert message3 != message4

    def test_message_hash(self):
        # Arrange
        message = Document(
            identifier=uuid4(),
            timestamp_ns=0,
        )

        # Act
        # Assert
        assert isinstance(hash(message), int)

    def test_message_str_and_repr(self):
        # Arrange
        uuid = uuid4()
        message = Document(
            identifier=uuid,
            timestamp_ns=0,
        )

        # Act
        # Assert
        assert str(message) == f"Document(id={uuid}, timestamp=0)"
        assert str(message) == f"Document(id={uuid}, timestamp=0)"

    def test_response_message_str_and_repr(self):
        # Arrange
        uuid_id = uuid4()
        uuid_corr = uuid4()
        message = Response(
            correlation_id=uuid_corr,
            identifier=uuid_id,
            timestamp_ns=0,
        )

        # Act
        # Assert
        assert str(message) == (
            f"Response(correlation_id={uuid_corr}, id={uuid_id}, timestamp=0)"
        )
        assert str(message) == (
            f"Response(correlation_id={uuid_corr}, id={uuid_id}, timestamp=0)"
        )

    @pytest.mark.parametrize(
        "msg_type, expected",
        [
            [MessageType.STRING, "STRING"],
            [MessageType.COMMAND, "COMMAND"],
            [MessageType.DOCUMENT, "DOCUMENT"],
            [MessageType.EVENT, "EVENT"],
            [MessageType.REQUEST, "REQUEST"],
            [MessageType.RESPONSE, "RESPONSE"],
        ],
    )
    def test_message_type_to_str(self, msg_type, expected):
        # Arrange
        # Act
        result = message_type_to_str(msg_type)

        # Assert
        assert result == expected

    @pytest.mark.parametrize(
        "string, expected",
        [
            ["STRING", MessageType.STRING],
            ["COMMAND", MessageType.COMMAND],
            ["DOCUMENT", MessageType.DOCUMENT],
            ["EVENT", MessageType.EVENT],
            ["REQUEST", MessageType.REQUEST],
            ["RESPONSE", MessageType.RESPONSE],
        ],
    )
    def test_message_type_from_str(self, string, expected):
        # Arrange
        # Act
        result = message_type_from_str(string)

        # Assert
        assert result == expected
