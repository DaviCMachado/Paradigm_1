{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StrictData #-}

import Web.Scotty
import Control.Monad.IO.Class (liftIO)
import qualified Data.Text.Lazy as T
import Data.Aeson (ToJSON, object, (.=))
import Data.Maybe (isJust)
import Control.Concurrent.MVar (MVar, newMVar, readMVar, modifyMVar_)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Text.Read (readMaybe)
import Network.Wai.Middleware.Static
import Control.Concurrent (putMVar)

-- Tipo para representar o estado do jogo
data GameState = GameState
    { board :: ![[Maybe String]]  -- Tabuleiro 3x3
    , currentPlayer :: !String     -- Jogador atual ("X" ou "O")
    }

-- Inicializa o estado do jogo
initialState :: GameState
initialState = GameState (replicate 3 (replicate 3 Nothing)) "X"

-- Armazena as salas de jogos
type Room = MVar GameState
type Rooms = Map String Room

-- Função para alternar jogadores
nextPlayer :: String -> String
nextPlayer "X" = "O"
nextPlayer "O" = "X"
nextPlayer _   = "X"

-- Função para fazer um movimento
makeMove :: GameState -> Int -> Int -> Either String GameState
makeMove (GameState board player) row col
    | row < 0 || row >= 3 || col < 0 || col >= 3 = Left "Movimento inválido!"
    | isJust (getCell board row col)               = Left "Posição já ocupada!"
    | otherwise                                   = Right $ GameState newBoard (nextPlayer player)
  where
    newRow = take col (getRow board row) ++ [Just player] ++ drop (col + 1) (getRow board row)
    newBoard = take row board ++ [newRow] ++ drop (row + 1) board

getRow :: [[a]] -> Int -> [a]
getRow board row = if row < length board then board !! row else []

getCell :: [[a]] -> Int -> Int -> a
getCell board row col = if col < length (getRow board row) then (getRow board row) !! col else error "Index out of bounds"

-- Função para verificar se há um vencedor
checkWinner :: [[Maybe String]] -> Maybe String
checkWinner b
    | any (all (== Just "X")) rows = Just "X"
    | any (all (== Just "O")) rows = Just "O"
    | otherwise                    = Nothing
  where
    rows = b ++ transpose b ++ [diagonal, reverseDiagonal]
    transpose ([]:_) = []
    transpose x     = map head x : transpose (map tail x)
    diagonal = [b !! i !! i | i <- [0..2]]
    reverseDiagonal = [b !! i !! (2 - i) | i <- [0..2]]

-- Função para lidar com a requisição de jogar
playMove :: Room -> Int -> Int -> IO (Either String (GameState, Maybe String))
playMove room row col = do
    currentState <- readMVar room
    let result = makeMove currentState row col
    case result of
        Left err -> return (Left err)
        Right newState -> do
            let winner = checkWinner (board newState)
            putMVar room newState
            return (Right (newState, winner))



-- Função para criar uma nova sala
createRoom :: MVar Rooms -> String -> IO (Either String Room)
createRoom roomsRef roomId = do
    rooms <- readMVar roomsRef
    if Map.member roomId rooms
        then return $ Left "Sala já existe!"
        else do
            newRoom <- newMVar initialState
            modifyMVar_ roomsRef $ \rooms -> do
                let updatedRooms = Map.insert roomId newRoom rooms
                liftIO $ putStrLn $ "Atualizando MVar com as novas salas: " ++ show (Map.keys updatedRooms)
                return updatedRooms
            return $ Right newRoom


-- Função para reiniciar o jogo
restartGame :: Room -> IO ()
restartGame room = putMVar room initialState

-- Função para listar as salas criadas
listRooms :: Rooms -> [String]
listRooms = Map.keys

main :: IO ()
main = do
    roomsRef <- newMVar Map.empty

    -- Inicia o servidor Scotty
    scotty 3000 $ do
        middleware $ staticPolicy (noDots >-> addBase "public")

        -- Rota para servir o arquivo HTML
        get "/" $ file "public/index.html"
  
        -- Rota para criar uma sala
        post "/sala/:id" $ do
            roomId <- param "id"
            liftIO $ putStrLn $ "Tentando criar a sala: " ++ roomId
            result <- liftIO $ createRoom roomsRef roomId
            case result of
                Left err -> do
                    liftIO $ putStrLn $ "Erro: " ++ err
                    json (object ["status" .= ("error" :: String), "message" .= T.pack err])
                Right _ -> do
                    liftIO $ putStrLn $ "Sala " ++ roomId ++ " criada com sucesso!"
                    json (object ["status" .= ("success" :: String), "message" .= T.pack ("Sala " ++ roomId ++ " criada!")])


        -- Rota para buscar o tabuleiro
        get "/sala/:id/tabuleiro" $ do
            roomId <- param "id"
            rooms <- liftIO $ readMVar roomsRef
            case Map.lookup roomId rooms of
                Just room -> do
                    currentState <- liftIO $ readMVar room
                    json (board currentState) -- Retorna o estado do tabuleiro
                Nothing -> json (object ["error" .= T.pack "Sala não encontrada!"])

        -- Rota para jogar uma jogada
        post "/sala/:id/jogar" $ do
            roomId <- param "id"
            row <- param "row"
            col <- param "col"
            rooms <- liftIO $ readMVar roomsRef
            case Map.lookup roomId rooms of
                Just room -> do
                    let maybeRow = readMaybe row :: Maybe Int
                    let maybeCol = readMaybe col :: Maybe Int
                    case (maybeRow, maybeCol) of
                        (Just r, Just c) -> do
                            result <- liftIO $ playMove room r c
                            case result of
                                Left err -> json (object ["error" .= T.pack err])
                                Right (newState, winner) -> do
                                    let message = case winner of
                                            Just w  -> T.pack (w ++ " ganhou!")
                                            Nothing -> T.pack ("Vez do jogador " ++ currentPlayer newState)
                                    json (object ["message" .= message, "board" .= board newState])
                        _ -> json (object ["error" .= T.pack "Parâmetros inválidos!"])
                Nothing -> json (object ["error" .= T.pack "Sala não encontrada!"])


        -- Rota para reiniciar o jogo
        post "/sala/:id/reiniciar" $ do
            roomId <- param "id"
            rooms <- liftIO $ readMVar roomsRef
            case Map.lookup roomId rooms of
                Just room -> do
                    liftIO $ restartGame room
                    json (object ["message" .= T.pack "Jogo reiniciado!"])
                Nothing -> json (object ["error" .= T.pack "Sala não encontrada!"])

        -- Rota para listar salas
        get "/salas" $ do
            rooms <- liftIO $ readMVar roomsRef
            let roomList = listRooms rooms
            json (object ["salas" .= roomList])

        -- Rota para listar todas as salas criadas
        get "/rooms" $ do
            rooms <- liftIO $ readMVar roomsRef
            let roomList = listRooms rooms
            json (object ["status" .= ("success" :: String), "rooms" .= roomList])

